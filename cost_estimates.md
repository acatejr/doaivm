# Cost Estimate: Running the VM for 1 Day

Based on the pricing noted in
[digitalocean-gpu-l40s-48gb-vm-plan.md](./digitalocean-gpu-l40s-48gb-vm-plan.md),
[digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md](./digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md),
[digitalocean-gpu-rtx4000ada-20gb-vm-plan.md](./digitalocean-gpu-rtx4000ada-20gb-vm-plan.md),
and
[digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md](./digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md)
(DigitalOcean Droplet pricing, Sept 2026). "1 day" = 24 hours of continuous uptime.

## GPU Plan — RTX 6000 Ada / L40S (48GB VRAM), TOR1

Module: [`gpu-qwen3-30b/`](./gpu-qwen3-30b)

| Item | Rate | 24h Cost |
|---|---|---|
| GPU droplet compute | ~$1.57/hr (roughly $2-3/hr class, per DO's published range for this GPU tier) | **~$37.68** |
| Model volume (100GB, `model_volume_size_gb` default) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.33 |
| **Total (1 day)** | | **~$38.00** |

At the higher end of DO's quoted $2-3/hr range for this GPU class, a full day could run
**~$48-72** instead. The plan doc flags this explicitly: destroy the droplet when not
in active use, since GPU droplets bill hourly regardless of utilization.

## GPU Plan — RTX 4000 Ada (20GB VRAM), TOR1

Module: [`gpu-rtx4000/`](./gpu-rtx4000)

Runs `qwen2.5-coder:14b` (dense, fits comfortably on-GPU at ~10-11GB used out of 20GB)
instead of the 30B MoE model used by the L40S/RTX 6000 Ada plan, which was flagged as
too tight for this smaller card.

| Item | Rate | 24h Cost |
|---|---|---|
| RTX 4000 Ada GPU droplet (20GB VRAM, 8 vCPU, 32GB RAM) | $0.76/hr | **$18.24** |
| Model volume (50GB, `model_volume_size_gb` default) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.16 |
| **Total (1 day)** | | **~$18.40** |

## GPU Plan — RTX 4000 Ada (20GB VRAM), TOR1, Llama 3.1 8B

Module: [`gpu-rtx4000-llama3/`](./gpu-rtx4000-llama3)

Same GPU tier as above, but built specifically to run "as quickly and cheaply as
possible": swaps in `llama3.1:8b` (dense, ~4.7GB download, ~6-7GB VRAM used including
KV cache) instead of a coding-specialized model. Smallest download and lowest
per-token compute of any of the four plans, at the cost of weaker code-specific
quality than the Qwen-based plans.

| Item | Rate | 24h Cost |
|---|---|---|
| RTX 4000 Ada GPU droplet (20GB VRAM, 8 vCPU, 32GB RAM) | $0.76/hr | **$18.24** |
| Model volume (30GB, `model_volume_size_gb` default) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.10 |
| **Total (1 day)** | | **~$18.34** |

Nearly identical daily rate to the Qwen2.5-Coder RTX 4000 Ada plan above (compute
dominates the cost, not storage) — the actual payoff of this plan is faster first-boot
setup and lower per-token latency, not a lower headline daily rate.

## CPU-Only Plan — CPU-Optimized 32GB / 16 vCPU, no GPU

Module: [`cpu-qwen3-30b/`](./cpu-qwen3-30b)

| Tier | RAM | vCPU | Disk | $/hr | 24h Cost | $/mo (730h) |
|---|---|---|---|---|---|---|
| **CPU-Optimized 32GB (recommended)** | 32GB | 16 | 200GB | $0.50 | **$12.00** | $336 |
| Memory-Optimized 32GB (cheapest fallback) | 32GB | 4 | 100GB | $0.25 | **$6.00** | $168 |

No separate volume — model weights live on the included boot disk, so there's no
additional storage line item.

## Summary Comparison (1 day / 24h)

| Plan | Module | 24h Cost |
|---|---|---|
| GPU — L40S/RTX 6000 Ada, `qwen3-coder:30b` (recommended GPU sizing) | `gpu-qwen3-30b/` | **~$38.00** |
| GPU — RTX 4000 Ada, `qwen2.5-coder:14b` | `gpu-rtx4000/` | **~$18.40** |
| GPU — RTX 4000 Ada, `llama3.1:8b` (quickest + cheapest to set up/run) | `gpu-rtx4000-llama3/` | **~$18.34** |
| CPU-Optimized 32GB/16vCPU, `qwen3-coder:30b` (recommended CPU tier) | `cpu-qwen3-30b/` | **$12.00** |
| Memory-Optimized 32GB/4vCPU, `qwen3-coder:30b` (cheapest fallback) | `cpu-qwen3-30b/` (override) | **$6.00** |

The two RTX 4000 Ada plans cost almost identically per day (~$18.30-18.40) since GPU
compute, not storage, dominates the cost — the Llama 3.1 8B variant's "quicker and
cheaper" advantage shows up in faster first-boot setup and lower per-token latency,
not in the daily rate. Both sit roughly in the middle: about **2x more per day** than
the CPU-Optimized plan but roughly **half the cost** of the L40S/RTX 6000 Ada plan,
while still running fully on-GPU. The CPU-Optimized plan costs roughly **3x less per
day** than the top-tier GPU plan, and the Memory-Optimized fallback costs roughly **6x
less**, at the cost of significantly lower inference throughput. All figures are
compute + (where applicable) storage only — they exclude bandwidth overages,
snapshots, or reserved IPs, none of which are enabled by default in any plan.
