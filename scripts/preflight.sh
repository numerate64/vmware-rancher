#!/usr/bin/env bash
set -euo pipefail

for command in terraform ansible-playbook jq ssh; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

echo "Local preflight passed."
