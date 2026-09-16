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

curl http://localhost:11434/api/generate -d '{"model":"qwen3-coder:30b","prompt":"write a hello world in rust","stream":false}'
```

## Teardown

GPU droplets bill hourly regardless of utilization. Destroy when not in active use:

```sh
terraform destroy
```
