#!/usr/bin/env bash
# Tear the droplet down to stop the hourly meter.
#
# Default: destroys the droplet + firewall only. The model volume (a few
# cents/day) is left in place so the next ./up.sh skips re-downloading the
# model. Pass --full to also destroy the volume for a true $0 while stopped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# shellcheck source=/dev/null
source "$SCRIPT_DIR/load-env.sh"

if [[ "${1:-}" == "--full" ]]; then
  echo "Full teardown: destroying droplet, firewall, AND the model volume."
  echo "Next ./up.sh will need to re-download the model."
  terraform destroy -auto-approve
else
  echo "Destroying droplet + firewall (keeping the model volume cached)."
  echo "Run with --full instead if you want the volume gone too."
  terraform destroy -auto-approve \
    -target=digitalocean_firewall.ollama \
    -target=digitalocean_droplet.ollama
fi
