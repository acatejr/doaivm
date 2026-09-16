#!/usr/bin/env bash
# Resumes this Claude Code session for the doaivm project.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

claude --resume 1cf5e97b-cbaf-4b38-97f1-91306068be57
