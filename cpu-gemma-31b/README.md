# CPU Root Module — Gemma 4 31B (no GPU)

Provisions a DigitalOcean CPU-only droplet running Ollama with `gemma4:31b`, private
only (Ollama bound to loopback, reached via SSH tunnel), following the same
architecture as [`../cpu-qwen3-30b`](../cpu-qwen3-30b).

## What was fixed here

This module started as a rough draft with several real bugs, found and fixed during
review:

- **Invalid droplet size**: `s-8vcpu-64gb` doesn't exist in DigitalOcean's size
  catalog at all (confirmed via the live sizes API) — `terraform apply` would have
  failed immediately. Replaced with `m-8vcpu-64gb` (Memory-Optimized, 8vCPU/64GB
  RAM), confirmed available in `nyc3`.
- **Duplicate Project creation**: the draft had its own
  `resource "digitalocean_project" "doaivm_project"`, which would either collide
  with or duplicate the account's single `doaivm` DigitalOcean Project already
  owned by [`../project`](../project) (DO Project names must be unique per account —
  see that module's README for why only it creates this resource). Replaced with a
  `data "digitalocean_project"` lookup, matching every other module in this repo.
- **Invalid resource type**: `digitalocean_project_resource` (singular) isn't a real
  resource in the DigitalOcean provider — the correct type is
  `digitalocean_project_resources` (plural), which also takes a droplet **URN**
  (`digitalocean_droplet.this.urn`), not a raw numeric ID. `terraform validate` would
  have failed on this immediately.
- **Wide-open security posture**: the draft bound Ollama to `OLLAMA_HOST=0.0.0.0`
  and opened port 11434 to `0.0.0.0/0` in the firewall — the entire internet could
  have reached the LLM API unauthenticated. Also opened SSH (port 22) to
  `0.0.0.0/0` with no allowlist mechanism (the `ssh_allowed_ips` variable used in
  `terraform.tfvars` wasn't even declared in `variables.tf`, so it was silently
  ignored). Fixed to match this repo's standard private-only posture: Ollama bound
  to `127.0.0.1`, no public inbound rule for it, and SSH properly restricted via a
  now-correctly-wired `ssh_allowed_ips` variable.
- **Missing `$HOME`**: the bootstrap script's `ollama pull` runs under `cloud-init`'s
  `runcmd`, which has no `$HOME` set — the `ollama` CLI panics
  (`panic: $HOME is not defined`) in that environment. This exact bug was found and
  fixed across every other module in this repo; same fix (`export HOME=/root`)
  applied here.
- **No SSH key resource**: the draft required a pre-registered
  `ssh_key_fingerprint` with no way to actually provide one via `terraform.tfvars`.
  Replaced with the same `digitalocean_ssh_key` + `ssh_public_key_path` pattern
  used everywhere else in this repo.
- Split the original single `main.tf` into `network.tf` / `droplet.tf` / `project.tf`
  and added `versions.tf`, matching this repo's file layout convention, and added a
  DigitalOcean Project assignment (`project.tf`) so this droplet shows up grouped
  with the others in the DO control panel.

**Note on `terraform.tfvars`**: it already had `ssh_allowed_ips = ["0.0.0.0/0", "::/0"]`
set. Before this fix that value was silently ignored (undeclared variable); now that
`ssh_allowed_ips` is wired up correctly, **it will actually take effect** — SSH will
genuinely be open to the whole internet if you apply as-is. That may be intentional
(this repo has used that value before for convenience during testing), but narrow it
to your own IP if you want the access restriction it implies.

## Prerequisites

- A DigitalOcean API token with write access.
- An SSH key pair (default expected path: `~/.ssh/id_ed25519.pub`).
- Terraform >= 1.16.
- The `doaivm` DigitalOcean Project already created — apply [`../project`](../project)
  once, first. This module assigns its droplet into that project via a
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

## Connecting

```sh
$(terraform output -raw ssh_command)            # direct SSH
$(terraform output -raw ssh_tunnel_command)      # open the Ollama tunnel (separate terminal)

curl http://localhost:11434/api/generate -d '{"model":"gemma4:31b","prompt":"write a hello world in rust","stream":false}'
```

`gemma4:31b` is a dense ~30.7B parameter model; expect noticeably slower generation
on CPU than the smaller models used elsewhere in this repo, though the 64GB RAM on
the default `droplet_size` gives it comfortable headroom to run.

## Teardown

```sh
terraform destroy
```

### DO Notes 

Estimated Digital Ocean Monthly Cost - $336/mo
Tell me a Joke Speed test - slow and very verbose.  Lot's of extraneous response content,