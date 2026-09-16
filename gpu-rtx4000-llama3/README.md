# GPU Root Module — RTX 4000 Ada (20GB VRAM), Llama 3.1 8B

Provisions a DigitalOcean GPU droplet running Ollama with `llama3.1:8b`, private only
(Ollama bound to loopback, reached via SSH tunnel). See
[../digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md](../digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md)
for full design rationale. This module exists specifically to run "as quickly and
cheaply as possible": it reuses the cheapest GPU tier available
([../gpu-rtx4000](../gpu-rtx4000)) but swaps in a much smaller model, so first-boot
model pull and inference are both faster than either the `gpu-qwen3-30b` or
`gpu-rtx4000` modules. Estimated cost: **~$18.34/day** if left running continuously
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

curl http://localhost:11434/api/generate -d '{"model":"llama3.1:8b","prompt":"write a hello world in rust","stream":false}'
```

After first boot, confirm the model is fully on-GPU: `nvidia-smi` should show
roughly 6-7GB used (not the full 20GB), with plenty of headroom to spare.

## Teardown

GPU droplets bill hourly regardless of utilization. Destroy when not in active use:

```sh
terraform destroy
```
