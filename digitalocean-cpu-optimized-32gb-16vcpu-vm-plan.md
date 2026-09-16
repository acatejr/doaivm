# Terraform: Ollama + Qwen3-Coder on a DigitalOcean CPU-Optimized Droplet (32GB RAM, 16 vCPU, No GPU)

## Context

Companion to the GPU plan
([digitalocean-gpu-l40s-48gb-vm-plan.md](./digitalocean-gpu-l40s-48gb-vm-plan.md)).
That plan is fast but expensive to leave running (~$1.57/hr, ~$38/day, ~$1,156/mo).
This plan targets the same goal — a solid Ollama-hosted coding assistant — but
prioritizes **low cost over speed**, by dropping the GPU entirely and running
inference on CPU.

Why this is still "a solid coding AI" despite no GPU: `qwen3-coder:30b` is a
**Mixture-of-Experts** model — 30B total parameters but only **3.3B active per
token**. That active-parameter count (not the total) is what drives per-token CPU
compute cost, so it's meaningfully more CPU-friendly than a dense 30B model would be.
Quality is identical to the GPU plan (same weights); the tradeoff is purely latency —
expect roughly single-digit-to-low-teens tokens/sec on 16 dedicated vCPUs rather than
GPU-class throughput, which is fine for iterative coding help but not for
high-volume/low-latency use.

Decisions carried over from the GPU plan (same rationale as before):
- **Model**: `qwen3-coder:30b` (19GB download, 256K context, verified via the Ollama
  library) — kept identical so quality is comparable; only the compute tier changes.
- **Exposure**: Private only — Ollama bound to loopback, reached via SSH tunnel.
- **State**: local `terraform.tfstate`, no remote backend.
- Same overall project conventions (variables, firewall approach, tftpl cloud-init)
  as the GPU plan, adapted below for a CPU-only host.

Pricing used (DigitalOcean Droplet pricing, Sept 2026):

| Tier | RAM | vCPU | Disk | $/hr | $/day (24h) | $/mo (730h) |
|---|---|---|---|---|---|---|
| **CPU-Optimized 32GB (recommended)** | 32GB | 16 | 200GB | $0.50 | **$12.00** | $336 |
| Memory-Optimized 32GB (cheapest fallback) | 32GB | 4 | 100GB | $0.25 | **$6.00** | $168 |

CPU-Optimized is the default: dedicated vCPUs and a 4x higher core count than
Memory-Optimized at the same RAM size directly translate into faster token generation
for llama.cpp/Ollama's multithreaded inference, and it's still ~3x cheaper per hour
than the GPU plan. Memory-Optimized is documented as a `droplet_size` override for
when cost matters more than responsiveness (e.g. batch/offline use).

32GB RAM is the floor: the 19GB model weights need to be fully resident, plus KV
cache and OS overhead. No separate storage volume is needed — unlike the GPU plan,
there's no ephemeral local-scratch disk to work around, so the model lives directly
on the droplet's normal persistent boot disk (200GB on the CPU-Optimized tier is
ample).

## Project layout

Add to the existing `/home/acatejr/workspace/doaivm/` project as a **separate,
parallel Terraform root** (its own directory, its own state) so either VM can be
applied/destroyed independently:

```
doaivm/
├── digitalocean-gpu-l40s-48gb-vm-plan.md            # existing GPU plan doc
├── digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md  # this plan doc
├── gpu-qwen3-30b/              # GPU root module (from the first plan)
│   └── ...
└── cpu-qwen3-30b/              # CPU-only root module (this plan)
    ├── versions.tf
    ├── providers.tf
    ├── variables.tf
    ├── network.tf              # digitalocean_vpc, digitalocean_firewall
    ├── droplet.tf                # ssh key, droplet (no GPU, no extra volume)
    ├── cloud-init.yaml.tftpl      # templated user_data
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── README.md
```

## Resources / variables

**providers.tf**: same as the GPU plan — `digitalocean/digitalocean` provider, token
from `var.do_token` (sensitive, sourced from env, never committed).

**variables.tf** (key ones, differences from the GPU plan noted):
- `do_token` (sensitive, no default)
- `region` — default `"nyc3"`. Unlike the GPU plan, no regional GPU-availability
  constraint applies, so any region is fine; pick one close to the operator.
- `droplet_size` — default `"c-16"` (CPU-Optimized, 32GB/16vCPU) *(verify current slug
  via `doctl compute size list` before apply — DO's slug naming can change)*; documented
  override to `"m-4vcpu-32gb"` (Memory-Optimized) for the cheaper/slower fallback.
- `image` — plain `"ubuntu-24-04-x64"` (no AI/ML-ready image needed — there's no GPU
  driver/CUDA stack to preinstall).
- `droplet_name` — default `"ollama-qwen3-coder-cpu"`.
- `ssh_public_key_path` — default `~/.ssh/id_ed25519.pub`.
- `ssh_allowed_ips` (list(string), **no default** — forces the operator to set it).
- `ollama_model` — default `"qwen3-coder:30b"`.
- `ollama_num_ctx` — default `32768`. The model supports up to 256K context, but on
  CPU the KV-cache memory and compute cost scale with context length, so it's capped
  well below the max to keep memory headroom and latency reasonable; overridable.

**network.tf**: identical pattern to the GPU plan — `digitalocean_vpc`, and a
`digitalocean_firewall` allowing inbound TCP 22 only from `var.ssh_allowed_ips`
(no inbound rule for 11434 — loopback-bound), outbound allow-all.

**droplet.tf**:
- `digitalocean_ssh_key` from `var.ssh_public_key_path`.
- `digitalocean_droplet`: `var.droplet_size` / `var.image`, VPC-attached, `user_data`
  = rendered cloud-init template, tags for identification.
- No `digitalocean_volume`/attachment — model stored on the boot disk at
  `/opt/ollama-models` (no ephemeral-disk workaround needed on non-GPU droplets).

**cloud-init.yaml.tftpl**, responsibilities (simpler than the GPU version — no driver
verification step):
1. `apt-get update && upgrade`.
2. Install Ollama via the official install script.
3. Systemd unit override for `ollama.service` setting:
   - `OLLAMA_MODELS=/opt/ollama-models`
   - `OLLAMA_HOST=127.0.0.1:11434` (loopback only, same private-only posture)
   - `OLLAMA_NUM_THREAD=<vCPU count>` (match `var.droplet_size`'s vCPUs, e.g. 16)
   - `OLLAMA_CONTEXT_LENGTH=${ollama_num_ctx}`
4. `systemctl daemon-reload && systemctl enable --now ollama`.
5. Oneshot step (with retry/wait-for-socket logic) running
   `ollama pull ${ollama_model}` on first boot.
6. Log a quick `ollama run qwen3-coder:30b --verbose "1+1"`-style smoke test to
   cloud-init output so first-boot latency/throughput is visible in the log without
   an extra manual SSH round-trip.

**outputs.tf**: `droplet_public_ip`, `droplet_private_ip`, `ssh_tunnel_command`
(`ssh -N -L 11434:localhost:11434 root@<ip>`), `ssh_command`.

**README.md**: same shape as the GPU plan's — prerequisites, init/plan/apply, tunnel
usage, example `curl`, and a note that this tier trades latency for a ~3-6x lower
run rate than the GPU plan.

## Verification plan

1. `terraform init && terraform validate && terraform plan` in `cpu-qwen3-30b/` —
   confirm the resolved `droplet_size` before applying.
2. `terraform apply`.
3. SSH in and check `systemctl status ollama` is active and `ollama list` shows
   `qwen3-coder:30b`.
4. From the local machine: open the SSH tunnel, then
   `curl http://localhost:11434/api/generate -d '{"model":"qwen3-coder:30b","prompt":"write a hello world in rust","stream":false}'`
   and time the response to sanity-check throughput is acceptable for interactive use.
5. `terraform destroy` when done — at this tier the always-on cost is low enough
   (~$6-12/day) that leaving it up for short stretches is far less punishing than the
   GPU plan, but destroying between extended idle periods is still the cheapest option.

## Open item to resolve during implementation

Confirm the live `droplet_size` slug for CPU-Optimized/Memory-Optimized 32GB tiers
(via `doctl compute size list` or the `digitalocean_sizes` data source) before the
first real apply, same caveat as the GPU plan — slugs weren't independently verified
against the live API during planning.
