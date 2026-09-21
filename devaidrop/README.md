# devaidrop — CPU-Optimized 32GB/16vCPU (no GPU)

A standalone copy of [`../cpu-qwen3-30b`](../cpu-qwen3-30b) with its own independent
identity (`droplet_name = "devaidrop"`, its own VPC/firewall/SSH key/state) so it can
be applied/destroyed without touching the original. Provisions a DigitalOcean
CPU-only droplet running Ollama with `qwen3-coder:30b`. See
[../digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md](../digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md)
for full design rationale. Estimated cost: **$12/day** (recommended CPU-Optimized
tier) or **$6/day** (Memory-Optimized fallback) if left running continuously — see
[../cost_estimates.md](../cost_estimates.md).

> **⚠️ Public, unauthenticated Ollama API — a deliberate exception to this
> repo's private-only posture.** Unlike every other module here, `OLLAMA_HOST`
> is bound to `0.0.0.0` and the firewall allows inbound TCP 11434 from
> `0.0.0.0/0`. Anyone who reaches the droplet's public IP can call the API with
> no auth and no rate limiting. This was requested explicitly, "for now" - not
> a pattern to copy into any other module. Tighten `ssh_allowed_ips`-style
> source restrictions or revert to loopback-only + SSH tunnel (see other
> modules' `network.tf`/`cloud-init.yaml.tftpl` for the pattern) once this is
> no longer needed.

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

The Ollama API is public - no tunnel required:

```sh
URL=$(terraform output -raw ollama_api_url)
curl $URL/api/generate -d '{"model":"qwen3-coder:30b","prompt":"write a hello world in rust","stream":false}'
```

```sh
$(terraform output -raw ssh_command)            # direct SSH, still private-key gated
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
