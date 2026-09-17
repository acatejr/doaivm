# CPU Root Module — CPU-Optimized 32GB/16vCPU (no GPU)

Provisions a DigitalOcean CPU-only droplet running Ollama with `qwen3-coder:30b`,
private only (Ollama bound to loopback, reached via SSH tunnel). See
[../digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md](../digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md)
for full design rationale. Estimated cost: **$12/day** (recommended CPU-Optimized
tier) or **$6/day** (Memory-Optimized fallback) if left running continuously — see
[../cost_estimates.md](../cost_estimates.md).

## Prerequisites

- A DigitalOcean API token with write access.
- An SSH key pair (default expected path: `~/.ssh/id_ed25519.pub`).
- Terraform >= 1.16.
- The `doaivm` DigitalOcean Project already created — apply [`../project`](../project)
  once, first. This module assigns its droplet/VPC into that project via a
  `data "digitalocean_project"` lookup by name, which fails if the project doesn't
  exist yet.

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set ssh_allowed_ips, and do_token if not using an env var

export TF_VAR_do_token="$DIGITALOCEAN_TOKEN"   # or set do_token in terraform.tfvars

terraform init
terraform validate
terraform plan   # review the resolved droplet_size before applying
terraform apply
```

To use the cheaper/slower Memory-Optimized fallback instead of the default
CPU-Optimized tier, set in `terraform.tfvars`:

```hcl
droplet_size      = "m-4vcpu-32gb"
ollama_num_thread = 4
```

## Connecting

```sh
$(terraform output -raw ssh_command)            # direct SSH
$(terraform output -raw ssh_tunnel_command)      # open the Ollama tunnel (separate terminal)

curl http://localhost:11434/api/generate -d '{"model":"qwen3-coder:30b","prompt":"write a hello world in rust","stream":false}'
```

Expect roughly single-digit-to-low-teens tokens/sec on the 16-vCPU tier — fine for
iterative coding help, not for high-volume/low-latency use.

## Teardown

```sh
terraform destroy
```

At this tier the always-on cost is low enough (~$6-12/day) that leaving it up for
short stretches is far less punishing than the GPU plans, but destroying between
extended idle periods is still the cheapest option.

### DO Notes 

Estimated Digital Ocean Monthly Cost - $336/mo
Tell me a Joke Speed test - very fast and succinct
