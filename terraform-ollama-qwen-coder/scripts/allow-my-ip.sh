#!/usr/bin/env bash
# Refreshes ONLY the firewall's SSH allowlist to your current public IP,
# without touching the droplet or volume. Use this if your public IP
# changes mid-session (switched wifi, laptop slept and rejoined a
# different network, toggled a VPN, ...) and SSH suddenly stops connecting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# shellcheck source=/dev/null
source "$SCRIPT_DIR/load-env.sh"

terraform apply -auto-approve -target=digitalocean_firewall.ollama

echo
terraform output ssh_command
