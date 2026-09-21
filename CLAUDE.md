# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This repo contains seven Terraform root modules: six independent VM modules, each
provisioning a DigitalOcean droplet running Ollama as a private backend, plus one
bootstrap module that owns the shared DigitalOcean *Project* (DO's resource-grouping
feature, unrelated to this repo's own name) all six droplets are assigned into.
Companion plan docs live alongside the four earliest modules (`cpu-gemma-31b/` and
`devaidrop/` have no plan doc - built directly as Terraform modules):

- `project/` — creates the DigitalOcean Project named `doaivm` (see its README).
  **Must be applied once, before the first apply of any of the six VM modules** —
  they each look this project up by name and fail if it doesn't exist yet.
- `gpu-qwen3-30b/` ([digitalocean-gpu-l40s-48gb-vm-plan.md](./digitalocean-gpu-l40s-48gb-vm-plan.md))
  — RTX 6000 Ada/L40S, 48GB VRAM, TOR1, `qwen3-coder:30b`. Fast but expensive
  (~$38/day if left running).
- `cpu-qwen3-30b/` ([digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md](./digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md))
  — CPU-Optimized 32GB/16vCPU (no GPU), `qwen3-coder:30b`. Cheaper ($12/day) and
  slower alternative to `gpu-qwen3-30b/`.
- `gpu-rtx4000/` ([digitalocean-gpu-rtx4000ada-20gb-vm-plan.md](./digitalocean-gpu-rtx4000ada-20gb-vm-plan.md))
  — designed for RTX 4000 Ada, 20GB VRAM, TOR1, `qwen2.5-coder:14b`, but that GPU
  size, and then its first fallback (the 48GB tier, `gpu-6000adax1-48gb`), both hit
  **zero available regions** on DigitalOcean in turn (confirmed live, 2026-09-16
  and 2026-09-17) — `droplet_size` now falls back further to `gpu-h100x1-80gb`
  (NVIDIA H100, the only GPU confirmed orderable in `tor1` at the second check) so
  the module stays usable. ~$106/day on this fallback (~$37.84/day on the 48GB
  fallback, ~$18.40/day if RTX 4000 Ada becomes available again — GPU capacity
  here has shifted within *minutes* between checks, so re-verify immediately
  before every apply rather than trusting any of these as current).
- `gpu-rtx4000-llama3/` ([digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md](./digitalocean-gpu-rtx4000ada-llama3-8b-vm-plan.md))
  — same original GPU tier as `gpu-rtx4000/` but `llama3.1:8b` instead, chosen to run
  "as quickly and cheaply as possible" over code-specific quality. Hit the same RTX
  4000 Ada unavailability and was moved to the same `gpu-6000adax1-48gb` fallback as
  `gpu-rtx4000/` originally was — but was **not** updated when `gpu-rtx4000/` moved
  again to `gpu-h100x1-80gb` (user explicitly scoped that fix to `gpu-rtx4000/`
  only), so it likely still points at the now-unavailable 48GB tier and probably
  needs the same live re-check/fallback treatment whenever it's next applied.
  ~$37.78/day on the fallback (~$18.34 if RTX 4000 Ada becomes available again).
- `cpu-gemma-31b/` — CPU-only (no GPU), `gemma4:31b` (dense ~30.7B params) on
  `m-8vcpu-64gb` (Memory-Optimized, 8vCPU/64GB RAM) in `nyc3`. Started as a rough
  draft with several real bugs (duplicate Project creation, an invalid
  `digitalocean_project_resource` resource type, a droplet size that doesn't exist
  at all in DO's catalog, Ollama and SSH both wide open to `0.0.0.0/0`, missing
  `$HOME` export) - all fixed in review; see its README's "What was fixed here" for
  the full list. No cost estimate added to `cost_estimates.md` yet.
- `devaidrop/` — a standalone copy of `cpu-qwen3-30b/` (same `qwen3-coder:30b` on
  CPU-Optimized `c-16`) made by literally copying that module's files, then giving
  it its own identity (`droplet_name = "devaidrop"`, so its VPC/firewall/SSH key
  don't collide with the original) and its own independent state - the `.terraform`
  cache, lock-file-pinned state, and `terraform.tfstate`/`.backup` were deliberately
  *not* copied from the original, since carrying over another module's state would
  make Terraform think this module already owns real, already-existing resources it
  doesn't. Same cost profile as `cpu-qwen3-30b/` (~$12/day). Runs Ollama only -
  no other service.
  - **Public Ollama API - a deliberate exception to this repo's private-only
    posture** (see the shared "Networking" bullet below): `OLLAMA_HOST` is
    bound to `0.0.0.0:11434` (not `127.0.0.1`) and `network.tf`'s firewall has
    an inbound rule allowing TCP 11434 from `0.0.0.0/0` - the API is reachable
    by anyone, unauthenticated, no rate limiting. Requested explicitly by the
    user ("for now") specifically for `devaidrop/`. `outputs.tf` exposes this
    as `ollama_api_url`; `ssh_tunnel_command` still exists as an alternative
    but is no longer required for access. Don't copy this pattern into any
    other module without being asked again, and don't assume it's still
    wanted if this file goes stale - confirm before treating it as permanent.
  - **History**: this module previously also ran a [LiteLLM](https://docs.litellm.ai/)
    proxy in front of Ollama (OpenAI-compatible `/v1/...` surface, its own venv,
    `litellm.service` systemd unit, `/ui` admin dashboard). It was removed entirely
    per explicit user request ("I only want it to run ollama and the llm model
    already in the project") - `cloud-init.yaml.tftpl`, `droplet.tf`, `variables.tf`,
    and `outputs.tf` no longer reference it, and it's back to matching
    `cpu-qwen3-30b/`'s shape. Don't re-add it without being asked again. If it ever
    does come back, several real gotchas were worked through in detail before
    removal - not re-derived here, but check `git log -p` for this file/module
    around 2026-09 if needed: a `curl -w "%{http_code}"` format string needing
    `%%{http_code}` escaping inside `templatefile()`; `'litellm[proxy]' prisma`
    needing to be installed together or failed-auth requests 500 instead of 401;
    `/ui` login being a hard dead end without a real connected Postgres database
    (master key alone is not enough); and, when using Supabase for that database,
    its direct-connection host being IPv6-only on newer/free-tier projects,
    requiring `ipv6 = true` on the droplet.
- `cost_estimates.md` — derived 1-day cost comparison across the first four VM
  modules (the `project/` module has no cost - DO Projects are a free organizational
  feature; `cpu-gemma-31b/` and `devaidrop/` haven't been added to this comparison
  yet - `devaidrop/`'s is identical to `cpu-qwen3-30b/`'s).

When extending or modifying any module, follow the project layout and resource
breakdown described in its companion `.md` file rather than improvising a different
structure (or, for `cpu-gemma-31b/`/`devaidrop/`, the pattern established by the
other four VM modules — see droplet.tf/network.tf/project.tf there for reference).
Each of the six VM modules keeps fully independent state (its own
`terraform.tfstate`) so any one VM can be applied/destroyed without affecting the
others — preserve that independence rather than merging them into a shared module.
`project/` is the sole exception by design: it's a shared singleton precisely because
DigitalOcean Project names must be unique per account, so it can't be safely created
redundantly from six separate states (see `project/README.md` for why) — never add a
`resource "digitalocean_project"`
to a VM module, only a `data "digitalocean_project"` lookup (this exact mistake was
found and fixed in `cpu-gemma-31b/`'s draft).

`ssh.sh` at the repo root is a convenience wrapper:
`./ssh.sh <gpu-qwen3-30b|cpu-qwen3-30b|gpu-rtx4000|gpu-rtx4000-llama3|cpu-gemma-31b|devaidrop>`
reads that module's `ssh_command` output and execs straight into an SSH session.

## Architecture (shared across all six VM modules)

All six modules share the same shape and are meant to stay parallel/independent
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
  **`devaidrop/` is the sole, explicit exception** - see its own bullet above
  for why and how; don't extend the exception to any other module without
  being asked.
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
  under `Restart=always` — this was a real bug hit and fixed across all four of
  these modules. Preserve the `mount/mkdir → install → chown → enable` ordering in
  any new module that customizes `OLLAMA_MODELS`. `cpu-gemma-31b/` sidesteps this
  bug entirely by design - it doesn't set `OLLAMA_MODELS` at all, so the model
  lives at Ollama's own default path, which the installer already creates owned by
  the `ollama` user it sets up. That's a valid alternative to the chown dance above
  whenever a module doesn't need a custom/persistent model directory.
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
  original `nyc3` default and `c-16`, since resolved by switching to `sfo3`; and with
  `gpu-qwen3-30b/`'s original `gpu-l40sx1-48gb` slug, which the live
  `GET /v2/sizes` API showed had zero available regions at all — resolved by
  switching to `gpu-6000adax1-48gb` (RTX 6000 Ada, the plan's other interchangeable
  48GB-VRAM option), available in `tor1`; and with `gpu-rtx4000/`'s original
  `gpu-4000adax1-20gb` (RTX 4000 Ada) slug, confirmed via both `GET /v2/sizes` and
  `GET /v2/regions` to be unorderable anywhere at all — no substitute exists at that
  price/VRAM point right now, so it falls back to the same `gpu-6000adax1-48gb` 48GB
  tier at roughly double the original cost estimate (see `cost_estimates.md`).
  `gpu-rtx4000-llama3/` hit the identical unavailable `gpu-4000adax1-20gb` size and
  got the same `gpu-6000adax1-48gb` fallback applied. GPU size availability shifts
  over time, so re-check both slug and region together, not just the slug in
  isolation, before every real apply — an empty `regions` list on `GET /v2/sizes`
  for a slug, or its absence from every region's `sizes` array on
  `GET /v2/regions`, means it isn't orderable anywhere right now, not just in the
  configured region.
  **This volatility is faster than assumed**: on 2026-09-17, `gpu-qwen3-30b/`'s
  `region` had been hand-edited to `sfo1` (not an orderable region at all - DO
  marks it `available: false`) and `droplet_size` to `gpu-6000adax1-48gb`, which
  by then showed zero available regions. Fixed back to `region = "tor1"` /
  `droplet_size = "gpu-l40sx1-48gb"`, confirmed available via both `/v2/sizes`
  and `/v2/regions` at the time. Minutes later, a re-check for `gpu-rtx4000/`
  and `gpu-rtx4000-llama3/` (still on `gpu-6000adax1-48gb`) showed **both**
  `gpu-l40sx1-48gb` and `gpu-6000adax1-48gb` back to zero available regions, and
  `tor1`'s live GPU list had changed again to just `gpu-mi325x1-256gb` and
  `gpu-h100x1-80gb`. Three checks a few minutes apart gave three different
  answers - this is real, fast-moving capacity constraint, not a caching
  artifact, and no hardcoded default can stay correct for long. Don't chase it
  with repeated fallback edits; check live immediately before each real apply,
  and expect to possibly retry if capacity vanishes between plan and apply.
  Sure enough, `gpu-rtx4000/`'s actual `terraform apply` then failed on
  `gpu-6000adax1-48gb` with the same 422 "Size is not available in this region"
  error - by then the only GPU confirmed orderable in `tor1` was
  `gpu-h100x1-80gb` (NVIDIA H100, $4.41/hr) or `gpu-mi325x1-256gb` (AMD
  MI325X, $3.80/hr, untested `gpu-amd-base`/ROCm path). Per explicit user
  instruction, only `gpu-rtx4000/` was moved to `gpu-h100x1-80gb` - a ~3x
  cost jump from the 48GB fallback (~$106/day vs ~$38/day) confirmed with the
  user before applying, given the size of the jump. `gpu-rtx4000-llama3/` was
  deliberately left on the now-also-broken `gpu-6000adax1-48gb` and will need
  the same live re-check next time it's applied - don't assume it still works
  just because `gpu-rtx4000/` was fixed.
- **The `ai_ml_ready` image data source was fundamentally broken, not just
  stale**: all three GPU modules used to auto-detect the image via
  `data "digitalocean_images"` filtered on `distribution = "Ubuntu"` and
  `regions = [var.region]`, sorted by `created desc`, taking `images[0]`. This
  is unsafe because that filter matches **any** image tagged `distribution =
  "Ubuntu"` - including private, third-party, and marketplace images on the
  account, not just official base OS releases. Confirmed live (2026-09-17):
  it first resolved to `openrouter-spawnopenclaw`, a private third-party
  marketplace image (`type = "application"`) unrelated to this project, which
  had already been deleted by the time it was queried again moments later
  (404 from `GET /v2/images/<id>`). Adding a `type = "base"` filter (the
  correct value in this data source's model - the DO REST API's own
  `?type=distribution` query param name does *not* match) narrowed it to only
  official base images, but then resolved to `gpu-h100x8-base` (an 8-GPU
  NVLink image) instead of the right one for a single-GPU droplet. Per
  DigitalOcean's own docs
  ([Recommended Drivers and Software for GPU Droplets](https://docs.digitalocean.com/products/droplets/getting-started/recommended-gpu-setup/)):
  **use `gpu-h100x1-base` for all single-GPU droplets regardless of GPU
  model, even non-H100 ones** - there is no L40S- or RTX-Ada-specific AI/ML
  Ready image; DO publishes exactly one image per GPU *count* (1x vs 8x), not
  per model. All three GPU modules now hardcode `var.image` default to
  `"gpu-h100x1-base"` directly and no longer use the data source at all - two
  wrong live resolutions from the same heuristic was enough to retire it
  rather than add a third filter. This image is required for functional GPU
  support: the cloud-init in these modules does not install NVIDIA
  drivers/CUDA itself, it relies entirely on the image already having them.
- **Shared SSH key collision across every module**: every module in this repo
  (the six `doaivm` VM modules including `devaidrop/`, `cpu-gemma-31b/`, and the
  standalone `terraform-ollama-qwen-coder/`) defaults `ssh_public_key_path` to the
  same `~/.ssh/id_ed25519.pub` and independently creates its own
  `digitalocean_ssh_key` resource from it. DigitalOcean deduplicates SSH keys
  by content/fingerprint, not by name - only the *first* module to actually
  apply successfully registers the key; every other module's own
  `digitalocean_ssh_key` create then fails with a 422 "SSH Key is already in
  use on your account", even though each uses a different resource `name`.
  Hit this live in `terraform-ollama-qwen-coder/` (the key had already been
  registered as `ollama-llama3-rtx4000-key` by `gpu-rtx4000-llama3/`). Fixed
  by `terraform import digitalocean_ssh_key.default <existing-key-id>` into
  the failing module's own state, which Terraform then reconciles as a safe
  in-place rename (`name` is not `ForceNew` on this resource) - not a
  destroy/recreate, and it doesn't affect the other module's tracking of the
  same key (tracked by ID, not display name) or anything already baked into a
  running droplet's `authorized_keys`. If this happens again in a new module,
  find the existing key's ID via `GET /v2/account/keys` (match by
  fingerprint - `ssh-keygen -lf ~/.ssh/id_ed25519.pub -E md5`) and import it
  the same way, rather than changing `ssh_public_key_path` to a different key.
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
after all six VM modules are destroyed (a non-default DO Project can't be deleted
while resources are still assigned to it).

Per VM module (`gpu-qwen3-30b/`, `cpu-qwen3-30b/`, `gpu-rtx4000/`,
`gpu-rtx4000-llama3/`, `cpu-gemma-31b/`, `devaidrop/`): `terraform init`, `terraform validate`, `terraform plan`
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

**Never read or write with `scratch` anywhere in its name**