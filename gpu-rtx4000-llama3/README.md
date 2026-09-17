# GPU Root Module — RTX 4000 Ada (20GB VRAM, currently falls back to 48GB), Llama 3.1 8B

Provisions a DigitalOcean GPU droplet running Ollama with `llama3.1:8b`, private only
(Ollama bound to loopback, reached via SSH tunnel). See
[../digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md](../digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md)
for full design rationale. This module exists specifically to run "as quickly and
cheaply as possible": it was designed to reuse the cheapest GPU tier available
([../gpu-rtx4000](../gpu-rtx4000)) but swap in a much smaller model, so first-boot
model pull and inference are both faster than either the `gpu-qwen3-30b` or
`gpu-rtx4000` modules.

**Current status**: RTX 4000 Ada (`gpu-4000adax1-20gb`, this module's original design
target) is confirmed via the live DigitalOcean sizes/regions APIs to have zero
available regions right now — not orderable anywhere on this account. `droplet_size`
falls back to `gpu-6000adax1-48gb` (48GB VRAM, the same tier `../gpu-qwen3-30b` and
`../gpu-rtx4000` use) so this module stays usable; `llama3.1:8b` still runs fine
there — the "quickly" part of this module's goal (small model, small download, low
per-token compute) still holds, only the "cheaply" part is compromised right now.
Estimated cost with the fallback: **~$37.78/day** (roughly double the original
~$18.34/day estimate) if left running continuously — see
[../cost_estimates.md](../cost_estimates.md). Re-check RTX 4000 Ada availability
periodically and switch `droplet_size` back if it returns.

## Prerequisites

- A DigitalOcean API token with write access.
- An SSH key pair (default expected path: `~/.ssh/id_ed25519.pub`).
- Terraform >= 1.16.
- The `doaivm` DigitalOcean Project already created — apply [`../project`](../project)
  once, first. This module assigns its droplet/volume/VPC into that project via a
  `data "digitalocean_project"` lookup by name, which fails if the project doesn't
  exist yet.
- (Optional but recommended) `doctl`, authenticated, to verify current GPU
  capacity before the first apply - see "Before the first apply" below.

## Before the first apply

`image` defaults to `gpu-h100x1-base`, DigitalOcean's documented AI/ML Ready image
for **all** single-GPU droplets regardless of GPU model (their own docs: "use
gpu-h100x1-base, even for single GPU plans using GPUs other than H100s") — this
shouldn't need changing. `droplet_size` and `region`, however, are subject to real,
fast-moving GPU capacity constraints (confirmed live: availability for this 48GB
tier has flipped within *minutes* between checks, not just days) — confirm both
together against the live API immediately before applying, since a value that
worked five minutes ago may not now:

```sh
doctl compute size list | grep -i gpu
```

Set the confirmed values in `terraform.tfvars` if they differ from the defaults, and
be prepared to retry if capacity vanishes between `plan` and `apply`.

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set ssh_allowed_ips, and do_token if not using an env var

export TF_VAR_do_token="$DIGITALOCEAN_TOKEN"   # or set do_token in terraform.tfvars

terraform init
terraform validate
terraform plan   # review the resolved droplet_size / image before applying
terraform apply
```

## Connecting

```sh
$(terraform output -raw ssh_command)            # direct SSH
$(terraform output -raw ssh_tunnel_command)      # open the Ollama tunnel (separate terminal)

curl http://localhost:11434/api/generate -d '{"model":"llama3.1:8b","prompt":"write a hello world in rust","stream":false}'
```

After first boot, confirm the model is fully on-GPU: `nvidia-smi` should show
roughly 6-7GB used out of the 48GB available on the current fallback tier (well
under capacity), with plenty of headroom to spare.

## Teardown

GPU droplets bill hourly regardless of utilization. Destroy when not in active use:

```sh
terraform destroy
```
