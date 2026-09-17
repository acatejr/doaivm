#!/usr/bin/env bash
# Connects to one of the doaivm droplets via SSH once it has been applied.
#
# Usage: ./ssh.sh <gpu-qwen3-30b|gpu-rtx4000|gpu-rtx4000-llama3|cpu-qwen3-30b|cpu-gemma-31b|devaidrop>
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <gpu-qwen3-30b|gpu-rtx4000|gpu-rtx4000-llama3|cpu-qwen3-30b|cpu-gemma-31b|devaidrop>" >&2
  exit 1
fi

module="$1"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
module_dir="${root_dir}/${module}"

if [[ ! -d "$module_dir" ]]; then
  echo "No such module: '${module}' (expected one of: gpu-qwen3-30b, gpu-rtx4000, gpu-rtx4000-llama3, cpu-qwen3-30b, cpu-gemma-31b, devaidrop)" >&2
  exit 1
fi

if ! cmd="$(terraform -chdir="$module_dir" output -raw ssh_command 2>/dev/null)"; then
  echo "Could not read the ssh_command output for '${module}'." >&2
  echo "Has it been applied yet? Try: terraform -chdir=${module} apply" >&2
  exit 1
fi

echo "+ ${cmd}" >&2
exec $cmd
