# GPU Root Module — RTX 4000 Ada (20GB VRAM, currently falls back to 48GB)

Provisions a DigitalOcean GPU droplet running Ollama with `qwen2.5-coder:14b`, private
only (Ollama bound to loopback, reached via SSH tunnel). See
[../digitalocean-gpu-rtx4000ada-20gb-vm-plan.md](../digitalocean-gpu-rtx4000ada-20gb-vm-plan.md)
for full design rationale, including why this tier uses a smaller/differently-shaped
model than the L40S/RTX 6000 Ada plan.

**Current status**: RTX 4000 Ada (`gpu-4000adax1-20gb`, this module's original design
target) is confirmed via the live DigitalOcean sizes/regions APIs to have zero
available regions right now — not orderable anywhere on this account. `droplet_size`
falls back to `gpu-6000adax1-48gb` (48GB VRAM, the same tier `../gpu-qwen3-30b` uses)
so this module stays usable; `qwen2.5-coder:14b` still runs fine there, just with far
more VRAM headroom than the original 20GB design intended. Estimated cost with the
fallback: **~$37.84/day** (roughly double the original ~$18.40/day estimate) if left
running continuously — see [../cost_estimates.md](../cost_estimates.md). Re-check RTX
4000 Ada availability periodically and switch `droplet_size` back if it returns.

## Prerequisites

- A DigitalOcean API token with write access.
- An SSH key pair (default expected path: `~/.ssh/id_ed25519.pub`).
- Terraform >= 1.16.
- The `doaivm` DigitalOcean Project already created — apply [`../project`](../project)
  once, first. This module assigns its droplet/volume/VPC into that project via a
  `data "digitalocean_project"` lookup by name, which fails if the project doesn't
  exist yet.
- (Optional but recommended) `doctl`, authenticated, to verify the GPU size and
  AI/ML Ready image slugs before the first apply.

## Before the first apply

The `droplet_size` and `image` defaults in this module are **placeholders**. Confirm
them against the live API:

```sh
doctl compute size list | grep -i gpu
doctl compute image list --public | grep -i "ai/ml"
```

Set the confirmed values in `terraform.tfvars` if they differ from the defaults.

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

curl http://localhost:11434/api/generate -d '{"model":"qwen2.5-coder:14b","prompt":"write a hello world in rust","stream":false}'
```

After first boot, confirm the model is fully on-GPU: `nvidia-smi` should show
~10-11GB used out of the 48GB available on the current fallback tier (well under
capacity), and generation latency should be GPU-class, not CPU-offloaded.

## Teardown

GPU droplets bill hourly regardless of utilization. Destroy when not in active use:

```sh
terraform destroy
```
