# GPU Root Module — RTX 6000 Ada / L40S (48GB VRAM)

Provisions a DigitalOcean GPU droplet running Ollama with `qwen3-coder:30b`, private
only (Ollama bound to loopback, reached via SSH tunnel). See
[../digitalocean-gpu-l40s-48gb-vm-plan.md](../digitalocean-gpu-l40s-48gb-vm-plan.md)
for full design rationale. Estimated cost: **~$38/day** if left running continuously
— see [../cost_estimates.md](../cost_estimates.md).

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

curl http://localhost:11434/api/generate -d '{"model":"qwen3-coder:30b","prompt":"write a hello world in rust","stream":false}'
```

## Teardown

GPU droplets bill hourly regardless of utilization. Destroy when not in active use:

```sh
terraform destroy
```
### DO Notes 

For some reason this one creates a volume that needs to be manually destoyed via the DO UI.
This droplet does not build as expected.
Estimated Digital Ocean Monthly Cost - $
Tell me a Joke Speed test - 
