# Terraform: Ollama + Qwen3-Coder on a DigitalOcean GPU Droplet (L40S/RTX 6000 Ada, 48GB VRAM, TOR1)

## Context

Goal: a Terraform project that provisions a DigitalOcean VM robust enough to run
Ollama serving `qwen3-coder`, for use as a local/private coding-assistant backend.
This is a greenfield project — no existing Terraform or related code. Terraform
v1.16.2 is available locally; `doctl` is not yet installed.

Decisions confirmed with the user:
- **Model**: `qwen3-coder:30b` (MoE, 30B total / 3.3B active params, 19GB download,
  256K context) — verified via the Ollama library. The 480B flagship needs ~250GB+
  memory and is out of scope for a single droplet.
- **Compute**: GPU Droplet (not CPU-only).
- **Exposure**: Private only — Ollama bound to loopback, reached via SSH tunnel. No
  public inbound on the API port.
- **State**: local `terraform.tfstate`, no remote backend.

Research findings that shape sizing (via DigitalOcean docs, Sept 2026):
- GPU Droplets are only available in specific regions per GPU type. Options that fit a
  single mid-size GPU for a 19GB quantized model: **NVIDIA RTX 6000 Ada** or **NVIDIA
  L40S** (both 48GB VRAM, region **TOR1**). H100 (80GB, NYC2/AMS3/TOR1) is oversized/
  pricier for this workload but is a fallback if RTX 6000 Ada/L40S capacity is
  unavailable. RTX 4000 Ada (20GB VRAM, TOR1) is likely too tight once KV-cache/context
  overhead is added on top of the 19GB weights, so it's not the default.
- DigitalOcean publishes an **AI/ML Ready** droplet image with NVIDIA drivers, CUDA, and
  container tooling preinstalled — avoids driver install in cloud-init.
- Exact GPU size **slugs** and the AI/ML-ready **image slug** are not reliably knowable
  without hitting the live API (they change and weren't fully enumerable via docs
  scraping). The plan handles this with a `digitalocean_sizes` / `digitalocean_images`
  data-source lookup plus a variable override, and calls this out as the one thing to
  confirm during `terraform plan` before first apply.

## Project layout

Create under `/home/acatejr/workspace/doaivm/`:

```
doaivm/
├── versions.tf              # terraform + provider version pins
├── providers.tf             # digitalocean provider config
├── variables.tf             # all inputs
├── network.tf                # digitalocean_vpc, digitalocean_firewall
├── droplet.tf                 # ssh key, GPU droplet, volume, volume attachment
├── cloud-init.yaml.tftpl      # templated user_data
├── outputs.tf                  # droplet IP, ssh + tunnel commands
├── terraform.tfvars.example
└── README.md                   # setup, apply, verify, teardown instructions
```

## Resources / variables

**providers.tf**: `digitalocean/digitalocean` provider, token from `var.do_token`
(marked sensitive, sourced from `DIGITALOCEAN_TOKEN`/`TF_VAR_do_token` env var — never
committed).

**variables.tf** (key ones):
- `do_token` (sensitive, no default)
- `region` (default `"tor1"`)
- `droplet_size` (default placeholder e.g. `"gpu-l40sx1-48gb"`, with a comment to verify
  via `doctl compute size list` or the `digitalocean_sizes` data source before apply)
- `image` (default: lookup via `digitalocean_images` data source filtered for the
  AI/ML-ready GPU image, region-scoped; overridable)
- `droplet_name` (default `"ollama-qwen3-coder"`)
- `ssh_public_key_path` (default `~/.ssh/id_ed25519.pub`)
- `ssh_allowed_ips` (list(string), **no default** — forces the operator to set their own
  IP/CIDR for SSH access)
- `ollama_model` (default `"qwen3-coder:30b"`)
- `model_volume_size_gb` (default `100`) — separate DO Volume so re-provisioning the
  droplet doesn't require re-downloading the model
- `enable_reserved_ip` (bool, default `false`) — optional stable public IP

**network.tf**:
- `digitalocean_vpc` for the droplet's private network.
- `digitalocean_firewall`: inbound TCP 22 restricted to `var.ssh_allowed_ips` only (no
  inbound rule for 11434, since Ollama is loopback-bound); outbound allow-all (needed for
  model pull + apt).

**droplet.tf**:
- `digitalocean_ssh_key` from `var.ssh_public_key_path`.
- `digitalocean_droplet`: GPU size/image above, VPC-attached, `user_data` = rendered
  cloud-init template, tags for identification.
- `digitalocean_volume` (size `var.model_volume_size_gb`, same region) +
  `digitalocean_volume_attachment` for persistent `/mnt/ollama-models`.
- Optional `digitalocean_reserved_ip` gated by `var.enable_reserved_ip`.

**cloud-init.yaml.tftpl** (rendered via `templatefile()`), responsibilities:
1. `apt-get update && upgrade` (base packages only — drivers come from the AI/ML image).
2. Wait for and format (if unformatted) + mount the attached volume at
   `/mnt/ollama-models`; add to `/etc/fstab`.
3. Install Ollama via the official install script
   (`curl -fsSL https://ollama.com/install.sh | sh`).
4. Drop a systemd unit override for `ollama.service` setting:
   - `OLLAMA_MODELS=/mnt/ollama-models`
   - `OLLAMA_HOST=127.0.0.1:11434` (loopback only — enforces the "private only" choice
     at the application layer, not just the firewall)
5. `systemctl daemon-reload && systemctl enable --now ollama`.
6. A oneshot step (with retry/wait-for-socket logic) that runs
   `ollama pull ${ollama_model}` on first boot so the droplet comes up ready to serve.
7. Write a `nvidia-smi` check to cloud-init output/journal for easy post-boot
   verification that the GPU is visible.

**outputs.tf**: `droplet_public_ip`, `droplet_private_ip`, a ready-to-copy
`ssh_tunnel_command` (`ssh -N -L 11434:localhost:11434 root@<ip>`), and `ssh_command`.

**README.md**: prerequisites (DO API token, doctl optional, SSH key registered),
`terraform init/plan/apply`, how to open the tunnel, example `curl`/`ollama` usage
against the tunneled endpoint, and a cost/teardown warning (see below).

## Verification plan

1. `terraform init && terraform validate && terraform plan` — confirm no errors, review
   the GPU size/image the data source resolves to before applying.
2. `terraform apply`.
3. SSH in directly (`ssh root@<droplet_public_ip>`) and check:
   - `nvidia-smi` shows the GPU.
   - `systemctl status ollama` is active.
   - `ollama list` shows `qwen3-coder:30b` pulled.
4. From the local machine: open the SSH tunnel from the `ssh_tunnel_command` output,
   then `curl http://localhost:11434/api/generate -d '{"model":"qwen3-coder:30b","prompt":"write a hello world in rust","stream":false}'`
   and confirm a valid completion comes back.
5. `terraform destroy` to confirm clean teardown (GPU droplets bill hourly — flag in the
   README that this should be destroyed or the flagship left running only when in use;
   RTX 6000 Ada/L40S class GPU droplets run roughly $2-3/hr, i.e. real money if left up
   continuously).

## Open item to resolve during implementation

Before the first real `apply`, confirm the live `droplet_size` slug and AI/ML-ready
`image` slug for TOR1 (via `doctl compute size list` / `doctl compute image list
--public` once `doctl` is installed and authenticated, or the `digitalocean_sizes`/
`digitalocean_images` Terraform data sources) — DigitalOcean's GPU catalog and slugs
weren't fully enumerable from docs alone and should be checked against the live API.
