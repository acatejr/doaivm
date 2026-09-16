# Terraform: Ollama + Llama 3.1 8B on a DigitalOcean GPU Droplet (RTX 4000 Ada, 20GB VRAM, TOR1)

## Context

Fourth variant alongside
[digitalocean-gpu-l40s-48gb-vm-plan.md](./digitalocean-gpu-l40s-48gb-vm-plan.md) (L40S/
RTX 6000 Ada, ~$38/day),
[digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md](./digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md)
(CPU-only, $12/day), and
[digitalocean-gpu-rtx4000ada-20gb-vm-plan.md](./digitalocean-gpu-rtx4000ada-20gb-vm-plan.md)
(RTX 4000 Ada + `qwen2.5-coder:14b`, ~$18.40/day). This plan targets a single, explicit
goal: **run Ollama as quickly and cheaply as possible**, not the strongest possible
coding assistant. That reframes both the GPU tier and the model choice compared to the
other three plans.

**GPU tier**: reuses the RTX 4000 Ada tier from the third plan — the cheapest GPU
DigitalOcean offers ($0.76/hr) — since "quickly" rules out CPU-only (the CPU plan runs
single-digit-to-low-teens tokens/sec) and "cheaply" rules out the larger 48GB tiers.

**Model choice: `llama3.1:8b`** — a dense 8B parameter Llama 3 model. At the default
`Q4_0` quantization it's roughly **4.7GB to download and hold in VRAM**, plus 1-2GB for
KV cache — around **6-7GB total**, leaving **13GB+ of headroom** on the RTX 4000 Ada's
20GB card. Two things make this the "quickly and cheaply" pick over the other plans'
models:
- **Smallest download of any model used across these four plans** (4.7GB vs. 9GB for
  `qwen2.5-coder:14b` or 19GB for `qwen3-coder:30b`) — first-boot setup finishes
  fastest here, which matters directly for "quickly" since droplets bill from the
  moment they're created, before the model has even finished pulling.
- **Fewer total and active parameters than either Qwen model** (8B dense, vs. 14B dense
  or 30B MoE) — lower per-token compute cost, so generation is the fastest of any of
  the four plans on equivalent hardware.

The tradeoff, explicitly accepted here: `llama3.1:8b` is a general-purpose model, not a
coding-specialized one like Qwen2.5-Coder or Qwen3-Coder. It's noticeably weaker at
code-specific tasks than the other three plans' models. If code quality matters more
than raw speed/cost, use [digitalocean-gpu-rtx4000ada-20gb-vm-plan.md](./digitalocean-gpu-rtx4000ada-20gb-vm-plan.md)
instead.

Decisions carried over from the other plans (same rationale as before):
- **Exposure**: Private only — Ollama bound to loopback, reached via SSH tunnel. No
  public inbound on the API port.
- **State**: local `terraform.tfstate`, own root module/state, independent of the
  other three roots so any VM can be applied/destroyed without affecting the others.
- Same overall project conventions (variables, firewall approach, tftpl cloud-init,
  and the `terraform_data.wait_for_setup` provisioner that blocks `apply` until
  cloud-init and the model pull are fully done) as the other plans.

Pricing used (DigitalOcean GPU Droplet pricing, Aug 2026, per-second billing with a
5-minute minimum):

| Item | Rate | 24h Cost |
|---|---|---|
| RTX 4000 Ada GPU droplet (20GB VRAM, 8 vCPU, 32GB RAM) | $0.76/hr | **$18.24** |
| Model volume (30GB, `model_volume_size_gb` default - smaller than the other GPU plans since the model is much smaller) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.10 |
| **Total (1 day)** | | **~$18.34** |

Effectively the same daily rate as the Qwen2.5-Coder RTX 4000 Ada plan (compute
dominates the cost, not storage) — the actual "cheaper and quicker" payoff of this plan
shows up in setup time (smaller download) and per-token latency (smaller/denser
model), not in the headline daily rate.

## Project layout

Add to the existing `/home/acatejr/workspace/doaivm/` project as a fourth, independent
Terraform root:

```
doaivm/
├── digitalocean-gpu-l40s-48gb-vm-plan.md                # L40S/RTX 6000 Ada plan doc
├── digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md      # CPU-only plan doc
├── digitalocean-gpu-rtx4000ada-20gb-vm-plan.md             # RTX 4000 Ada + Qwen plan doc
├── digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md         # this plan doc
├── gpu-qwen3-30b/                 # L40S/RTX 6000 Ada root module
├── cpu-qwen3-30b/                 # CPU-only root module
├── gpu-rtx4000/                  # RTX 4000 Ada + qwen2.5-coder:14b root module
└── gpu-rtx4000-llama3/            # RTX 4000 Ada + llama3.1:8b root module (this plan)
    ├── versions.tf
    ├── providers.tf
    ├── variables.tf
    ├── network.tf                  # digitalocean_vpc, digitalocean_firewall
    ├── droplet.tf                    # ssh key, GPU droplet, volume, volume attachment,
    │                                  # wait_for_setup provisioner
    ├── cloud-init.yaml.tftpl          # templated user_data
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── README.md
```

## Resources / variables

Identical shape to
[digitalocean-gpu-rtx4000ada-20gb-vm-plan.md](./digitalocean-gpu-rtx4000ada-20gb-vm-plan.md)'s
module, with these differences:

- `droplet_name` (default `"ollama-llama3-rtx4000"`)
- `ollama_model` (default `"llama3.1:8b"`)
- `model_volume_size_gb` (default `30`, down from 50 - the model is roughly half the
  download size)
- All other variables (`do_token`, `region` default `"tor1"`, `droplet_size` default
  `"gpu-4000adax1-20gb"`, `image`, `ssh_public_key_path`, `ssh_private_key_path`,
  `ssh_allowed_ips`, `enable_reserved_ip`) match the Qwen2.5-Coder RTX 4000 Ada plan
  exactly, including the same live-API-verification caveats on `droplet_size`/`image`.

**cloud-init.yaml.tftpl** responsibilities are identical to the other GPU plans' (mount
the model volume, install Ollama via the official script, configure the loopback-bound
systemd unit, pull the model on first boot, verify `nvidia-smi`) - only the pulled
model tag and the VRAM sanity-check message differ.

**droplet.tf** includes the same `terraform_data.wait_for_setup` resource as the other
three modules: it depends on the firewall and volume attachment, SSHes in once they're
ready, streams `/var/log/cloud-init-output.log` live, and blocks `terraform apply`
until `cloud-init status --wait` reports done - so "Apply complete!" means the model is
already pulled and ready, not just that the droplet exists.

## Verification plan

1. `terraform init && terraform validate && terraform plan` — confirm no errors,
   review the GPU size/image the data source resolves to before applying.
2. `terraform apply` — expect this to finish noticeably faster than the other two GPU
   plans, since the model download is much smaller.
3. SSH in directly (`ssh root@<droplet_public_ip>`, or via `../ssh.sh gpu-rtx4000-llama3`)
   and check:
   - `nvidia-smi` shows the GPU and reports VRAM usage consistent with the model
     (roughly 6-7GB used, not the full 20GB).
   - `systemctl status ollama` is active.
   - `ollama list` shows `llama3.1:8b` pulled.
4. From the local machine: open the SSH tunnel from the `ssh_tunnel_command` output,
   then `curl http://localhost:11434/api/generate -d '{"model":"llama3.1:8b","prompt":"write a hello world in rust","stream":false}'`
   and confirm a valid completion comes back quickly.
5. `terraform destroy` to confirm clean teardown (GPU droplets bill hourly — destroy
   when not in active use, same as the other GPU plans).

## Open item to resolve during implementation

Before the first real `apply`, confirm the live `droplet_size` slug and AI/ML-ready
`image` slug for the RTX 4000 Ada tier in TOR1 (via `doctl compute size list` /
`doctl compute image list --public`, or the `digitalocean_sizes`/`digitalocean_images`
Terraform data sources) — same caveat as the other three plans: exact slugs weren't
independently verified against the live API during planning. Also worth noting: earlier
testing of the CPU plan hit a "Size is not available in this region" error for a
different droplet_size/region combination, which is a useful reminder that a plausible
slug isn't the same as an available one in the target region - verify both together,
not just the slug in isolation.
