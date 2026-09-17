# devaidrop — CPU-Optimized 32GB/16vCPU (no GPU) + LiteLLM

A standalone copy of [`../cpu-qwen3-30b`](../cpu-qwen3-30b) with its own independent
identity (`droplet_name = "devaidrop"`, its own VPC/firewall/SSH key/state) so it can
be applied/destroyed without touching the original. Provisions a DigitalOcean
CPU-only droplet running Ollama with `qwen3-coder:30b`, private only (Ollama bound to
loopback, reached via SSH tunnel). See
[../digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md](../digitalocean-cpu-optimized-32gb-16vcpu-vm-plan.md)
for full design rationale. Estimated cost: **$12/day** (recommended CPU-Optimized
tier) or **$6/day** (Memory-Optimized fallback) if left running continuously — see
[../cost_estimates.md](../cost_estimates.md).

**Devaidrop-only addition**: this module also installs
[LiteLLM](https://docs.litellm.ai/)'s proxy server, giving the Ollama model an
OpenAI-compatible `/v1/...` API surface — useful for tools that expect an
OpenAI-shaped client rather than Ollama's native API. LiteLLM is installed into its
own Python venv (`/opt/litellm-venv`, isolated from system Python — Ubuntu 24.04
blocks system-wide `pip install`), runs as a systemd service (`litellm.service`,
`Requires=ollama.service`), and is configured (`/etc/litellm/config.yaml`) to proxy
`qwen3-coder:30b` to the local Ollama API. It keeps the same private-only posture as
Ollama itself: bound to `127.0.0.1:4000`, no public firewall rule, reachable only via
its own SSH tunnel. This is **not** present in `cpu-qwen3-30b/` or any other module —
it was added to this module specifically.

**Auth**: LiteLLM requires `var.litellm_master_key` (no default — set it in
`terraform.tfvars`, e.g. `openssl rand -hex 24`). This key is the Bearer token
required on every `/v1/...` API call — fully working, verified end-to-end (see
"Via LiteLLM" below).

**Admin UI (`/ui`) does not work here, by design decision — not a bug to fix**:
LiteLLM's `/ui` login flow requires an actual connected Postgres database (via
Prisma) — it calls `user_update()` on every login attempt regardless of master-key
correctness, which raises `Exception: Not connected to DB!` and a `400` on
`POST /v2/login` when no `DATABASE_URL` is configured, which this module
deliberately doesn't provision (would mean either installing Postgres on this same
droplet or paying for a separate DigitalOcean Managed Database). The master key
still fully works for its actual purpose - authenticating `/v1/...` API calls -
just not for the web dashboard's login screen. If UI access becomes worth the added
cost/complexity later, this module would need a database added first.

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
# edit terraform.tfvars: set ssh_allowed_ips, litellm_master_key (e.g. `openssl
# rand -hex 24`), and do_token if not using an env var

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

### Via LiteLLM (OpenAI-compatible)

```sh
$(terraform output -raw litellm_tunnel_command)  # open the LiteLLM tunnel (separate terminal)
KEY=$(terraform output -raw litellm_master_key)

curl http://localhost:4000/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" -d '{
  "model": "qwen3-coder:30b",
  "messages": [{"role": "user", "content": "write a hello world in rust"}]
}'
```

Or point any OpenAI-client library at `base_url="http://localhost:4000/v1"` with
`api_key` set to `terraform output -raw litellm_master_key` and
`model="qwen3-coder:30b"`.

### Admin UI — not functional (see "Admin UI does not work here" above)

`http://localhost:4000/ui` loads and the login form accepts input, but submitting
it always fails (`400`, "Not connected to DB!") since no database is configured.
Use the API directly instead (above).

## Teardown

```sh
terraform destroy
```

At this tier the always-on cost is low enough (~$6-12/day) that leaving it up for
short stretches is far less punishing than the GPU plans, but destroying between
extended idle periods is still the cheapest option.
