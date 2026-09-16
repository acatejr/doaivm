# Terraform: Ollama + Qwen2.5-Coder on a DigitalOcean GPU Droplet (RTX 4000 Ada, 20GB VRAM, TOR1)

## Context

Third variant alongside
[digitalocean-gpu-l40s-48gb-vm-plan.md](./digitalocean-gpu-l40s-48gb-vm-plan.md) (L40S/
RTX 6000 Ada, 48GB VRAM, ~$38/day) and
[digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md](./digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md)
(CPU-only, ~$12/day). This plan targets the smallest DigitalOcean GPU tier —
**NVIDIA RTX 4000 Ada, 20GB VRAM** — as a middle ground: real GPU throughput at a
lower hourly rate than the L40S/RTX 6000 Ada tier, while still fitting entirely on-GPU
(no CPU offload) with a right-sized model.

**Why not `qwen3-coder:30b` here**: the GPU plan already flagged that RTX 4000 Ada's
20GB is "likely too tight" for `qwen3-coder:30b`'s 19GB of weights once KV-cache and
context overhead are added — there'd be little headroom left and any bump in context
length risks an OOM. This plan picks a differently-sized model instead of trying to
force the same one onto smaller hardware.

**Model choice: `qwen2.5-coder:14b`** — a dense 14B parameter model purpose-built for
code generation, completion, debugging, and refactoring across dozens of languages,
with 128K context support. At the default `Q4_K_M` quantization it needs **~8.7GB of
VRAM for weights** (per Qwen's published GGUF sizes); adding 1-2GB for KV cache at
typical context lengths keeps total usage around **10-11GB**, leaving roughly
**9-10GB of headroom** on the 20GB card for larger context windows or batched
requests — a comfortable fit, unlike the 30B MoE model. It's dense rather than MoE
(no active-parameter shortcut), but at 14B total parameters that's not a problem on a
dedicated GPU the way it would be on CPU.

Decisions carried over from the other two plans (same rationale as before):
- **Exposure**: Private only — Ollama bound to loopback, reached via SSH tunnel. No
  public inbound on the API port.
- **State**: local `terraform.tfstate`, no remote backend, own root module/state
  (independent of the `gpu-qwen3-30b/` and `cpu-qwen3-30b/` roots so all three VMs can be
  applied/destroyed independently).
- Same overall project conventions (variables, firewall approach, tftpl cloud-init) as
  the other two plans, adapted below for this GPU/model pairing.

Pricing used (DigitalOcean GPU Droplet pricing, Aug 2026, per-second billing with a
5-minute minimum):

| Item | Rate | 24h Cost |
|---|---|---|
| RTX 4000 Ada GPU droplet (20GB VRAM, 8 vCPU, 32GB RAM) | $0.76/hr | **$18.24** |
| Model volume (50GB, `model_volume_size_gb` default) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.16 |
| **Total (1 day)** | | **~$18.40** |

This lands roughly in between the CPU plan ($12/day) and the L40S/RTX 6000 Ada plan
(~$38/day) — see `cost_estimates.md` for the full three-way comparison.

## Project layout

Add to the existing `/home/acatejr/workspace/doaivm/` project as a third, independent
Terraform root:

```
doaivm/
├── digitalocean-gpu-l40s-48gb-vm-plan.md               # L40S/RTX 6000 Ada plan doc
├── digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md     # CPU-only plan doc
├── digitalocean-gpu-rtx4000ada-20gb-vm-plan.md            # this plan doc
├── gpu-qwen3-30b/               # L40S/RTX 6000 Ada root module
├── cpu-qwen3-30b/               # CPU-only root module
└── gpu-rtx4000/                # RTX 4000 Ada root module (this plan)
    ├── versions.tf
    ├── providers.tf
    ├── variables.tf
    ├── network.tf               # digitalocean_vpc, digitalocean_firewall
    ├── droplet.tf                 # ssh key, GPU droplet, volume, volume attachment
    ├── cloud-init.yaml.tftpl       # templated user_data
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── README.md
```

## Resources / variables

**providers.tf**: same as the other plans — `digitalocean/digitalocean` provider,
token from `var.do_token` (sensitive, sourced from `DIGITALOCEAN_TOKEN`/
`TF_VAR_do_token` env var, never committed).

**variables.tf** (key ones, differences from the L40S plan noted):
- `do_token` (sensitive, no default)
- `region` (default `"tor1"`) — RTX 4000 Ada is a region-constrained GPU tier like the
  other GPU options; TOR1 is where DigitalOcean has offered it alongside RTX 6000
  Ada/L40S.
- `droplet_size` (default placeholder e.g. `"gpu-4000adax1-20gb"`, with a comment to
  verify via `doctl compute size list` or the `digitalocean_sizes` data source before
  apply — exact slug not independently confirmed against the live API during
  planning).
- `image` (default: lookup via `digitalocean_images` data source filtered for the
  AI/ML-ready GPU image, region-scoped; overridable) — same AI/ML Ready image approach
  as the L40S plan, avoiding a manual driver/CUDA install in cloud-init.
- `droplet_name` (default `"ollama-qwen2.5-coder-rtx4000"`)
- `ssh_public_key_path` (default `~/.ssh/id_ed25519.pub`)
- `ssh_allowed_ips` (list(string), **no default** — forces the operator to set their
  own IP/CIDR for SSH access)
- `ollama_model` (default `"qwen2.5-coder:14b"`)
- `model_volume_size_gb` (default `50`) — smaller than the L40S plan's 100GB default
  since the model is ~9GB quantized rather than 19GB; a separate DO Volume still keeps
  re-provisioning the droplet from requiring a re-download.
- `enable_reserved_ip` (bool, default `false`) — optional stable public IP

**network.tf**: identical pattern to the other two plans —
`digitalocean_vpc` for the droplet's private network, and a `digitalocean_firewall`
with inbound TCP 22 restricted to `var.ssh_allowed_ips` only (no inbound rule for
11434, since Ollama is loopback-bound); outbound allow-all (needed for model pull +
apt).

**droplet.tf**:
- `digitalocean_ssh_key` from `var.ssh_public_key_path`.
- `digitalocean_droplet`: GPU size/image above, VPC-attached, `user_data` = rendered
  cloud-init template, tags for identification.
- `digitalocean_volume` (size `var.model_volume_size_gb`, same region) +
  `digitalocean_volume_attachment` for persistent `/mnt/ollama-models`.
- Optional `digitalocean_reserved_ip` gated by `var.enable_reserved_ip`.

**cloud-init.yaml.tftpl** (rendered via `templatefile()`), responsibilities — same
shape as the L40S plan's:
1. `apt-get update && upgrade` (base packages only — drivers come from the AI/ML
   image).
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
   verification that the GPU is visible and the full model fits on-GPU (watch for any
   CPU-offload warnings in the Ollama logs, which would mean the sizing assumption
   above needs revisiting).

**outputs.tf**: `droplet_public_ip`, `droplet_private_ip`, a ready-to-copy
`ssh_tunnel_command` (`ssh -N -L 11434:localhost:11434 root@<ip>`), and `ssh_command`.

**README.md**: prerequisites (DO API token, doctl optional, SSH key registered),
`terraform init/plan/apply`, how to open the tunnel, example `curl`/`ollama` usage
against the tunneled endpoint, and a cost/teardown warning (see below).

## Verification plan

1. `terraform init && terraform validate && terraform plan` — confirm no errors,
   review the GPU size/image the data source resolves to before applying.
2. `terraform apply`.
3. SSH in directly (`ssh root@<droplet_public_ip>`) and check:
   - `nvidia-smi` shows the GPU and reports VRAM usage consistent with the model
     (roughly 10-11GB used, not the full 20GB, once idle after warmup).
   - `systemctl status ollama` is active.
   - `ollama list` shows `qwen2.5-coder:14b` pulled.
4. From the local machine: open the SSH tunnel from the `ssh_tunnel_command` output,
   then `curl http://localhost:11434/api/generate -d '{"model":"qwen2.5-coder:14b","prompt":"write a hello world in rust","stream":false}'`
   and confirm a valid completion comes back with GPU-class latency (not
   CPU-offloaded, which would show as sharply slower generation).
5. `terraform destroy` to confirm clean teardown (GPU droplets bill hourly — flag in
   the README that this should be destroyed or left running only when in use; at
   $0.76/hr this tier is cheaper than the L40S/RTX 6000 Ada class but still real money
   if left up continuously — see `cost_estimates.md`).

## Open item to resolve during implementation

Before the first real `apply`, confirm the live `droplet_size` slug and AI/ML-ready
`image` slug for the RTX 4000 Ada tier in TOR1 (via `doctl compute size list` /
`doctl compute image list --public` once `doctl` is installed and authenticated, or
the `digitalocean_sizes`/`digitalocean_images` Terraform data sources) — same caveat
as the other two plans: exact slugs weren't independently verified against the live
API during planning.
