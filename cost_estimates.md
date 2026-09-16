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

## GPU Plan — RTX 4000 Ada (20GB VRAM), TOR1 — currently falls back to 48GB

Module: [`gpu-rtx4000/`](./gpu-rtx4000)

Runs `qwen2.5-coder:14b` (dense, fits comfortably on-GPU at ~10-11GB used) instead of
the 30B MoE model used by the L40S/RTX 6000 Ada plan.

**Live-availability note (2026-09-16)**: RTX 4000 Ada (`gpu-4000adax1-20gb`) has zero
available regions right now on DigitalOcean's live sizes/regions APIs — the original
$18.40/day estimate below assumed that tier. Until it's available again, this module
falls back to `gpu-6000adax1-48gb` (the same 48GB tier `gpu-qwen3-30b/` uses):

| Item | Rate | 24h Cost |
|---|---|---|
| GPU droplet compute (48GB VRAM fallback) | $1.57/hr | **~$37.68** |
| Model volume (50GB, `model_volume_size_gb` default) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.16 |
| **Total (1 day, current fallback)** | | **~$37.84** |

Original 20GB-tier estimate, for reference (once/if RTX 4000 Ada is available again):

| Item | Rate | 24h Cost |
|---|---|---|
| RTX 4000 Ada GPU droplet (20GB VRAM, 8 vCPU, 32GB RAM) | $0.76/hr | **$18.24** |
| Model volume (50GB, `model_volume_size_gb` default) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.16 |
| **Total (1 day, if available)** | | **~$18.40** |

## GPU Plan — RTX 4000 Ada (20GB VRAM), TOR1, Llama 3.1 8B — currently falls back to 48GB

Module: [`gpu-rtx4000-llama3/`](./gpu-rtx4000-llama3)

Same original GPU tier as above, built specifically to run "as quickly and cheaply as
possible": swaps in `llama3.1:8b` (dense, ~4.7GB download, ~6-7GB VRAM used including
KV cache) instead of a coding-specialized model. Smallest download and lowest
per-token compute of any of the four plans, at the cost of weaker code-specific
quality than the Qwen-based plans.

**Live-availability note (2026-09-16)**: RTX 4000 Ada (`gpu-4000adax1-20gb`) has zero
available regions right now on DigitalOcean's live sizes/regions APIs — the original
$18.34/day estimate below assumed that tier. Until it's available again, this module
falls back to `gpu-6000adax1-48gb` (the same 48GB tier `gpu-qwen3-30b/` and
`gpu-rtx4000/` use):

| Item | Rate | 24h Cost |
|---|---|---|
| GPU droplet compute (48GB VRAM fallback) | $1.57/hr | **~$37.68** |
| Model volume (30GB, `model_volume_size_gb` default) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.10 |
| **Total (1 day, current fallback)** | | **~$37.78** |

Original 20GB-tier estimate, for reference (once/if RTX 4000 Ada is available again):

| Item | Rate | 24h Cost |
|---|---|---|
| RTX 4000 Ada GPU droplet (20GB VRAM, 8 vCPU, 32GB RAM) | $0.76/hr | **$18.24** |
| Model volume (30GB, `model_volume_size_gb` default) | $0.10/GB-mo ≈ $0.00329/GB-day | ~$0.10 |
| **Total (1 day, if available)** | | **~$18.34** |

The "quickly" half of this plan's goal (small model, small download, low per-token
compute) still holds on the fallback tier — only the "cheaply" half is compromised
until RTX 4000 Ada returns.

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
| GPU — RTX 4000 Ada → 48GB fallback, `qwen2.5-coder:14b` (see note above) | `gpu-rtx4000/` | **~$37.84** (~$18.40 if RTX 4000 Ada returns) |
| GPU — RTX 4000 Ada → 48GB fallback, `llama3.1:8b` (see note above) | `gpu-rtx4000-llama3/` | **~$37.78** (~$18.34 if RTX 4000 Ada returns) |
| CPU-Optimized 32GB/16vCPU, `qwen3-coder:30b` (recommended CPU tier) | `cpu-qwen3-30b/` | **$12.00** |
| Memory-Optimized 32GB/4vCPU, `qwen3-coder:30b` (cheapest fallback) | `cpu-qwen3-30b/` (override) | **$6.00** |

All three GPU modules currently converge on the same 48GB-VRAM tier (`gpu-6000adax1-48gb`)
since neither of the smaller/cheaper GPU sizes this repo originally targeted
(L40S, RTX 4000 Ada) is orderable right now — the difference between them today is
purely which model each pulls, not hardware cost. The CPU-Optimized plan costs
roughly **3x less per day** than any GPU module right now, and the Memory-Optimized
fallback costs roughly **6x less**, at the cost of significantly lower inference
throughput. All figures are compute + (where applicable) storage only — they
exclude bandwidth overages, snapshots, or reserved IPs, none of which are enabled
by default in any plan.
