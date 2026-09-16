# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This repo contains five Terraform root modules: four independent VM modules, each
provisioning a DigitalOcean droplet running Ollama as a private backend, plus one
bootstrap module that owns the shared DigitalOcean *Project* (DO's resource-grouping
feature, unrelated to this repo's own name) all four droplets are assigned into.
Companion plan docs live alongside them:

- `project/` — creates the DigitalOcean Project named `doaivm` (see its README).
  **Must be applied once, before the first apply of any of the four VM modules** —
  they each look this project up by name and fail if it doesn't exist yet.
- `gpu-qwen3-30b/` ([digitalocean-gpu-l40s-48gb-vm-plan.md](./digitalocean-gpu-l40s-48gb-vm-plan.md))
  — RTX 6000 Ada/L40S, 48GB VRAM, TOR1, `qwen3-coder:30b`. Fast but expensive
  (~$38/day if left running).
- `cpu-qwen3-30b/` ([digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md](./digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md))
  — CPU-Optimized 32GB/16vCPU (no GPU), `qwen3-coder:30b`. Cheaper ($12/day) and
  slower alternative to `gpu-qwen3-30b/`.
- `gpu-rtx4000/` ([digitalocean-gpu-rtx4000ada-20gb-vm-plan.md](./digitalocean-gpu-rtx4000ada-20gb-vm-plan.md))
  — RTX 4000 Ada, 20GB VRAM, TOR1, `qwen2.5-coder:14b` (right-sized for this smaller
  card). ~$18.40/day.
- `gpu-rtx4000-llama3/` ([digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md](./digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md))
  — same GPU tier as `gpu-rtx4000/` but `llama3.1:8b` instead, chosen to run "as
  quickly and cheaply as possible" over code-specific quality. ~$18.34/day.
- `cost_estimates.md` — derived 1-day cost comparison across all four VM modules
  (the `project/` module has no cost - DO Projects are a free organizational feature).

When extending or modifying any module, follow the project layout and resource
breakdown described in its companion `.md` file rather than improvising a different
structure. Each of the four VM modules keeps fully independent state (its own
`terraform.tfstate`) so any one VM can be applied/destroyed without affecting the
others — preserve that independence rather than merging them into a shared module.
`project/` is the sole exception by design: it's a shared singleton precisely because
DigitalOcean Project names must be unique per account, so it can't be safely created
redundantly from four separate states (see `project/README.md` for why).

`ssh.sh` at the repo root is a convenience wrapper:
`./ssh.sh <gpu-qwen3-30b|cpu-qwen3-30b|gpu-rtx4000|gpu-rtx4000-llama3>` reads that
module's `ssh_command` output and execs straight into an SSH session.

## Architecture (shared across all four modules)

All four modules share the same shape and are meant to stay parallel/independent
Terraform roots (separate `terraform.tfstate` each) rather than one shared module,
so any one VM can be applied/destroyed without affecting the others:

- **Provider**: `digitalocean/digitalocean`, token from `var.do_token` (sensitive,
  sourced from `DIGITALOCEAN_TOKEN`/`TF_VAR_do_token` env var — never committed, never
  hardcoded in `.tfvars`).
- **Networking**: a `digitalocean_vpc` plus a `digitalocean_firewall` that allows
  inbound TCP 22 only from `var.ssh_allowed_ips` (no default — operator must set it).
  Ollama's port (11434) is intentionally **not** exposed by the firewall or by the
  application: `OLLAMA_HOST` is bound to `127.0.0.1` inside the droplet, and access is
  only via SSH tunnel (`ssh -N -L 11434:localhost:11434 root@<ip>`). Preserve this
  private-only posture — don't add a public inbound rule for the Ollama port.
- **Provisioning**: a single `digitalocean_droplet` with `user_data` rendered from a
  `cloud-init.yaml.tftpl` template (via `templatefile()`). Cloud-init installs Ollama,
  configures the systemd unit (model path, host binding, thread/context settings), and
  pulls the model on first boot.
- **Model directory ownership**: the official `ollama.com/install.sh` creates an
  unprivileged `ollama` system user and a systemd unit that runs the daemon as that
  user (`User=ollama Group=ollama`). Every module's `runcmd` therefore does
  `curl ... install.sh | sh` **before** `chown ollama:ollama` on the model directory
  (`/opt/ollama-models` for `cpu-qwen3-30b/`, `/mnt/ollama-models` for the three GPU
  modules) — the directory/mount is created and mounted earlier in `runcmd`, but must
  not be handed to the `ollama` user until that user actually exists. Skipping the
  `chown`, or putting it before the install step, leaves the directory owned by
  `root:root` and the service fails to initialize its model store and crash-loops
  under `Restart=always` — this was a real bug hit and fixed across all four modules.
  Preserve the `mount/mkdir → install → chown → enable` ordering in any new module.
- **`$HOME` in `ollama-first-boot.sh`**: `cloud-init`'s `runcmd` executes with no
  `$HOME` set, and the `ollama` CLI panics (`panic: $HOME is not defined`) during its
  own init if it's missing — this hit the `ollama pull`/`ollama run` client
  invocations in every module's first-boot script (not the systemd service itself,
  which gets its environment from the unit file's `Environment=` lines, not a shell).
  Every module's `ollama-first-boot.sh` therefore starts with `export HOME=/root`
  right after `set -euo pipefail`, before any `ollama` CLI call. Verified live on a
  real `cpu-qwen3-30b/` droplet: without the export, `ollama pull` panicked
  immediately; with it, the pull and a generate smoke test both succeeded. Keep this
  export in any new module's first-boot script.
- **Model storage**: the three GPU plans (`gpu-qwen3-30b/`, `gpu-rtx4000/`,
  `gpu-rtx4000-llama3/`) each use a separate `digitalocean_volume` (mounted at
  `/mnt/ollama-models`) so re-provisioning the droplet doesn't require re-downloading
  the model — sized per module to roughly match its model's download size
  (100GB/50GB/30GB respectively). The `cpu-qwen3-30b/` plan has no GPU-driven
  ephemeral-disk constraint, so the model lives directly on the boot disk
  (`/opt/ollama-models`) — don't add a volume to the CPU variant, it's an intentional
  simplification.
- **Size/image slugs are not hardcoded as verified values**: every plan flags that
  exact DigitalOcean `droplet_size` and `image` slugs must be confirmed against the
  live API (`doctl compute size list` / `doctl compute image list --public`, or the
  `digitalocean_sizes`/`digitalocean_images` Terraform data sources) before the first
  real `apply` — don't treat the slugs written in the plan docs as guaranteed current
  or guaranteed available in the configured region (a `droplet_size` can exist but
  not be orderable in a given region — hit this in practice with `cpu-qwen3-30b/`'s
  original `nyc3` default and `c-16`, since resolved by switching to `sfo3`).
- **DigitalOcean Project assignment**: each VM module has a `project.tf` with a
  `data "digitalocean_project" { name = var.do_project_name }` lookup (default
  `"doaivm"`) and a `digitalocean_project_resources` resource assigning that
  module's droplet (+ volume, for the GPU modules) into it via their `urn`
  attributes. **VPCs and firewalls are NOT valid project resource types** — DO's
  API rejects them (confirmed via a live 400 response enumerating the allowed
  types: AppPlatformApp, Bucket, ByoipPrefix, Database, Domain, DomainRecord,
  Droplet, DropletSnapshot, Firewall, FloatingIp, GenAiAgent, GenAiKnowledgeBase,
  Image, Kubernetes, LoadBalancer, MarketplaceApp, NatGateway, ReservedIPv6, Saas,
  Volume, VolumeSnapshot — note "Firewall" *is* technically listed, but the
  `digitalocean_firewall` Terraform resource exposes no `urn` attribute to pass
  it with, so it's left out too). `digitalocean_vpc.this.urn` exists in the
  provider schema but must NOT be passed here despite that — it will fail at
  apply time. Preserve this pattern (droplet + volume only) in any new VM module
  rather than leaving its droplet in DO's default project.

## Commands

`project/` first (once, before any VM module's first apply): `terraform init`,
`terraform validate`, `terraform plan`, `terraform apply`, `terraform destroy` only
after all four VM modules are destroyed (a non-default DO Project can't be deleted
while resources are still assigned to it).

Per VM module (`gpu-qwen3-30b/`, `cpu-qwen3-30b/`, `gpu-rtx4000/`,
`gpu-rtx4000-llama3/`): `terraform init`, `terraform validate`, `terraform plan`
(review the resolved size/image before applying), `terraform apply` (returns once
the droplet resource itself is created — cloud-init/Ollama setup then continues in
the background; SSH in and check `cloud-init status` or tail
`/var/log/cloud-init-output.log` if you need to confirm it's finished), and
`terraform destroy` for teardown (every plan calls out destroying when not in
active use, since droplets bill hourly regardless of utilization). Run
`terraform fmt -recursive` from the repo root after editing any `.tf` file.

## Secrets and env files

**Never read or write any file with `.env` anywhere in its name** (e.g. `.env`,
`.env.local`, `.env.production`, `something.env.bak`), in this repo or elsewhere in
the working tree. Treat such files as strictly off-limits — do not open them to
"check" values, and do not create or edit them even if asked to set an environment
variable. DigitalOcean credentials belong in the `DIGITALOCEAN_TOKEN` /
`TF_VAR_do_token` shell environment or an untracked `terraform.tfvars`, never in a
`.env`-named file that gets read into context.
