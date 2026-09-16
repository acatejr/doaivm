#!/usr/bin/env bash
# Sourced by up.sh / down.sh. Loads a .env file (project root) if present,
# then maps whatever you called your DigitalOcean token to TF_VAR_do_token,
# which is the name Terraform will automatically feed into var.do_token in
# variables.tf -- no -var flags, no editing terraform.tfvars needed.
#
# Terraform only auto-picks-up environment variables named TF_VAR_<name>;
# it does not read .env files on its own, so this is the glue for that.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a # export every variable sourced below, not just ones we name
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

# Accept whatever key you used in .env and normalize it to TF_VAR_do_token.
# Already-set TF_VAR_do_token (e.g. exported in your shell) wins.
export TF_VAR_do_token="${TF_VAR_do_token:-${DIGITALOCEAN_TOKEN:-${DO_TOKEN:-${DO_API_TOKEN:-}}}}"

if [[ -z "${TF_VAR_do_token:-}" ]]; then
  echo "ERROR: no DigitalOcean token found." >&2
  echo "Put one of these in $ROOT_DIR/.env (see .env.example):" >&2
  echo "  DIGITALOCEAN_TOKEN=dop_v1_..." >&2
  echo "  DO_TOKEN=dop_v1_..." >&2
  echo "  TF_VAR_do_token=dop_v1_..." >&2
  echo "...or export one of those yourself, or set do_token in terraform.tfvars." >&2
  exit 1
fi

# --- Auto-detect your current public IP and authorize it for SSH ---
#
# ssh_allowed_ips is a CIDR allowlist on the DigitalOcean firewall. A laptop
# that roams between networks (home wifi, a cafe, a hotspot) gets a
# different public IP on each one, so a value pinned in terraform.tfvars
# would lock you out the moment you're not on the network you applied from.
# Instead, unless you've already set TF_VAR_ssh_allowed_ips yourself (or
# left an active ssh_allowed_ips line in terraform.tfvars, which takes
# priority -- see the README), every up.sh/down.sh run re-detects your
# current public IP and authorizes exactly that.
detect_public_ip() {
  local ip=""
  for url in "https://ifconfig.me" "https://api.ipify.org" "https://icanhazip.com"; do
    ip="$(curl -fsS --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')" || true
    if [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
      printf '%s' "$ip"
      return 0
    fi
  done
  return 1
}

if [[ -z "${TF_VAR_ssh_allowed_ips:-}" ]]; then
  echo "Detecting current public IP to authorize for SSH..." >&2
  if CURRENT_PUBLIC_IP="$(detect_public_ip)"; then
    export TF_VAR_ssh_allowed_ips="[\"${CURRENT_PUBLIC_IP}/32\"]"
    echo "Authorizing SSH from ${CURRENT_PUBLIC_IP}/32 for this run." >&2
  else
    echo "WARNING: could not auto-detect your public IP (offline, or ifconfig.me/ipify/icanhazip all unreachable)." >&2
    echo "Set ssh_allowed_ips manually in terraform.tfvars, or export TF_VAR_ssh_allowed_ips='[\"x.x.x.x/32\"]' yourself, then re-run." >&2
  fi
else
  echo "Using SSH allowlist already set in TF_VAR_ssh_allowed_ips: $TF_VAR_ssh_allowed_ips" >&2
fi
