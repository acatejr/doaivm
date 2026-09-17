# Ollama + Qwen2.5-Coder 7B on a DigitalOcean Droplet

Terraform config for the cheapest practical DigitalOcean setup discussed:
an 8GB/4vCPU Basic Droplet running Ollama with `qwen2.5-coder:7b`, billed
hourly, meant to be spun up for a coding session and torn down when idle.

## What this creates

- One `s-4vcpu-8gb` Basic Droplet (~$0.071/hr, ~$48/mo if left running 24/7)
- One 10GB block Volume, mounted at `/mnt/ollama_models`, that stores the
  pulled model. It's intentionally decoupled from the droplet's lifecycle --
  see "Idle teardown" below.
- A firewall that only allows SSH from your IP by default. The Ollama API
  (port 11434) is **not** exposed publicly unless you opt in.
- An SSH key resource built from a local public key you already have.
- Cloud-init (`templates/bootstrap.sh.tftpl`) that installs Ollama, points
  its model storage at the volume, and runs `ollama pull qwen2.5-coder:7b`
  on first boot.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- A DigitalOcean account and [API token](https://cloud.digitalocean.com/account/api/tokens)
  (needs read/write scope)
- An SSH key pair on your machine (`ssh-keygen -t ed25519` if you don't have one)

## Setup

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- `ssh_public_key_path` — path to your public key (default assumes `~/.ssh/id_ed25519.pub`)
- `ssh_allowed_ips` — leave this commented out unless you specifically want a
  fixed allowlist. By default `scripts/up.sh`/`down.sh` detect your current
  public IP automatically on every run (see "Working from a roaming laptop"
  below) — there's no safe *static* default here on purpose, an open SSH
  port to the world isn't one.

`terraform.tfvars` is gitignored so your token and IP never get committed.

### Supplying the DigitalOcean token from a `.env` file

Terraform doesn't read `.env` files itself -- it only auto-picks-up
environment variables named `TF_VAR_<variable name>` (so `TF_VAR_do_token`
maps straight to `var.do_token` in `variables.tf`, no `-var` flags needed).

This repo bridges that gap for you:

```bash
cp .env.example .env
# edit .env, put your real token in it
```

`scripts/up.sh` and `scripts/down.sh` both source `scripts/load-env.sh`
first, which loads `.env` if it exists and exports `TF_VAR_do_token` from
whichever key you used (`DIGITALOCEAN_TOKEN`, `DO_TOKEN`, or
`TF_VAR_do_token` directly -- pick whichever your `.env` already has). Then
just run `./scripts/up.sh` as normal; you never touch `terraform.tfvars` for
the token.

`.env` is gitignored. Two things worth knowing:
- Don't also set `do_token` in `terraform.tfvars` -- a value there takes
  priority over the environment variable and will silently win, so if you
  edit `.env` and nothing changes, check for a stray `do_token = "..."`
  line in `terraform.tfvars`.
- If you're calling `terraform` directly instead of the scripts (e.g.
  `terraform plan`), export the variable in your shell first:
  `set -a && source .env && set +a && export TF_VAR_do_token=$DIGITALOCEAN_TOKEN`,
  or just run `terraform` through `scripts/up.sh` / `down.sh` which do this
  for you.

## Usage

```bash
chmod +x scripts/*.sh

./scripts/up.sh      # creates the droplet, billing starts
# ... work happens here ...
./scripts/down.sh    # destroys the droplet + firewall, billing stops
```

First boot takes a few minutes (installing Ollama + pulling ~4.7GB for the
7B model). `terraform output` after `up.sh` gives you:

- `ssh_command` — plain SSH access
- `ollama_tunnel_command` — the recommended way to reach the API: tunnels
  port 11434 over SSH so it's never exposed to the internet. Run it, then
  point any Ollama/OpenAI-compatible client at `http://localhost:11434`.
- `bootstrap_log_check` — tails the install log so you can confirm the
  model finished pulling before you start using it

Quick end-to-end test once bootstrap is done:

```bash
ssh -N -L 11434:localhost:11434 root@$(terraform output -raw droplet_ip) &
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-coder:7b",
  "prompt": "Write a Python function that reverses a linked list.",
  "stream": false
}'
```

## Working from a roaming laptop (DHCP, changing wifi/hotspots)

The firewall only allows SSH from an IP allowlist (`ssh_allowed_ips`), and a
static CIDR would lock you out the moment your laptop is on a different
network than when you applied it — home wifi, a cafe, a phone hotspot, or
just an ISP that rotates your address, all give you a different *public*
IP. (This is separate from DHCP on your local network, which only assigns
your private LAN address.)

To handle that, `scripts/load-env.sh` — sourced by every script below —
auto-detects your current public IP (via ifconfig.me, falling back to
ipify.org and icanhazip.com) and passes it as `TF_VAR_ssh_allowed_ips` on
every run, unless you've explicitly overridden it. In practice this means:

- `./scripts/up.sh` — authorizes whatever network you're on right now
- `./scripts/down.sh` — same, since Terraform still evaluates the variable
  even for a targeted destroy
- `./scripts/allow-my-ip.sh` — if your IP changes **mid-session** (laptop
  slept and rejoined a different network, you toggled a VPN, etc.) and SSH
  suddenly stops connecting, run this to refresh just the firewall rule
  without touching the droplet or losing your work

If you'd rather have a fixed allowlist instead (e.g. you always work from a
static-IP office network), uncomment `ssh_allowed_ips` in
`terraform.tfvars` — a value set there overrides the auto-detection.

## Idle teardown -- the two ways to go cheap

DigitalOcean bills for a droplet's whole existence, not just CPU time, so
the only way to actually stop paying for it is to destroy it. `down.sh`
gives you two levels:

**`./scripts/down.sh` (default)** — destroys the droplet and firewall,
*keeps* the model volume. You keep paying for the volume alone (~$0.10/GB-mo,
so ~$1/mo for the default 10GB, prorated by the hour) but the next `up.sh`
skips the ~4.7GB re-download and is ready in under a minute.

**`./scripts/down.sh --full`** — destroys everything, including the volume.
Truly $0 while stopped, but the next `up.sh` re-downloads the model
(a few minutes, depending on DigitalOcean's network speed at the time).

For occasional coding sessions, the default (keep the volume) is almost
always worth the ~3 cents/day. Use `--full` if you're stopping for a long
stretch (weeks) and don't mind the re-download.

## Cost summary (as of Sept 2026 DigitalOcean pricing)

| Item | Rate | Notes |
|---|---|---|
| Droplet (s-4vcpu-8gb) | $0.071/hr (~$48/mo) | Only while `up` |
| Volume (10GB) | ~$0.10/GB-mo ≈ $1/mo | Billed whether droplet exists or not, unless you `--full` teardown |

10 hours of coding a month ≈ $0.71 droplet + ~$0.03 prorated volume ≈ **under $1/month**.

## Security notes

- SSH is restricted to `ssh_allowed_ips`, auto-refreshed to your current
  public IP on every `up.sh`/`down.sh`/`allow-my-ip.sh` run (see "Working
  from a roaming laptop" above) unless you've pinned a fixed value in
  `terraform.tfvars`.
- The Ollama API is bound on the droplet to all interfaces (`OLLAMA_HOST=0.0.0.0`)
  but the DigitalOcean firewall — not the app — is what actually blocks
  external access by default. Prefer the SSH tunnel over setting
  `ollama_allowed_ips` unless you have a specific reason to expose it.
- The droplet is created with only the SSH key you provide; no password auth.

## Changing the model or size

- Smaller/faster: set `model_name = "qwen2.5-coder:3b"` (fits comfortably,
  faster responses, less capable).
- Bigger/better: `model_name = "qwen2.5-coder:14b"` needs more headroom —
  bump `droplet_size` to `s-8vcpu-16gb` (~16GB RAM) and `volume_size_gb` to
  at least 15, and expect CPU inference to be noticeably slower.
- Don't shrink `droplet_size` below 8GB for the 7B model — the ~5GB model
  plus OS/Ollama overhead doesn't leave a comfortable margin below that.

## Cleanup

`./scripts/down.sh --full` removes everything this config created. Double
check in the DigitalOcean dashboard that no droplet, volume, or firewall
named `ollama-qwen-coder*` is left behind if you ever run commands outside
these scripts.

### DO Notes
Cost: $49/mo -- $0.073 / hour
Tell me a Joke Speed Test: Medium.  Slow rendering to screen.
Overall not a bad option for the price.