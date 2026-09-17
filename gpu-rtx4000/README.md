# GPU Root Module — RTX 4000 Ada (20GB VRAM, currently falls back to H100 80GB)

Provisions a DigitalOcean GPU droplet running Ollama with `qwen2.5-coder:14b`, private
only (Ollama bound to loopback, reached via SSH tunnel). See
[../digitalocean-gpu-rtx4000ada-20gb-vm-plan.md](../digitalocean-gpu-rtx4000ada-20gb-vm-plan.md)
for full design rationale, including why this tier uses a smaller/differently-shaped
model than the L40S/RTX 6000 Ada plan.

**Current status**: RTX 4000 Ada (`gpu-4000adax1-20gb`, this module's original design
target) and the entire 48GB tier (`gpu-l40sx1-48gb` / `gpu-6000adax1-48gb`, the first
fallback used here) are all confirmed via the live DigitalOcean sizes/regions APIs to
have zero available regions right now. GPU capacity in this account/region has been
observed to shift within *minutes*, not days. `droplet_size` currently falls back to
`gpu-h100x1-80gb` (NVIDIA H100, the only GPU confirmed orderable in `tor1` at last
check besides a pricier untested-here AMD option) so this module stays usable;
`qwen2.5-coder:14b` still runs fine there, with substantial headroom beyond the
original 20GB design. Estimated cost with this fallback: **~$106/day** (roughly 3x
the ~$37.84/day 48GB-fallback estimate, and ~6x the original ~$18.40/day estimate) if
left running continuously — see [../cost_estimates.md](../cost_estimates.md).
Re-check GPU availability immediately before every apply and switch `droplet_size`
back to something cheaper the moment it's orderable again.

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

curl http://localhost:11434/api/generate -d '{"model":"qwen2.5-coder:14b","prompt":"write a hello world in rust","stream":false}'
```

After first boot, confirm the model is fully on-GPU: `nvidia-smi` should show
~10-11GB used out of the 80GB available on the current fallback tier (well under
capacity), and generation latency should be GPU-class, not CPU-offloaded.

## Teardown

GPU droplets bill hourly regardless of utilization. Destroy when not in active use:

```sh
terraform destroy
```

### DO Notes 

Estimated Digital Ocean Monthly Cost - $4.418 / hour
Tell me a Joke Speed test - Speed was ok.  Not too slow, but not fast either.

