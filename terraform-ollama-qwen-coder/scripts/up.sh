#!/usr/bin/env bash
# Spin the droplet up (starts the hourly meter).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# shellcheck source=/dev/null
source "$SCRIPT_DIR/load-env.sh"

terraform init -input=false
terraform apply -auto-approve

echo
echo "Up. First boot needs a few minutes to install Ollama and pull the model."
echo
terraform output
