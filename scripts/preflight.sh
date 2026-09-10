#!/usr/bin/env bash
set -euo pipefail

for command in terraform ansible-playbook jq ssh; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

test -f "${HOME}/.ssh/aqtech-rancher_ed25519" || {
  echo "Expected private key at ~/.ssh/aqtech-rancher_ed25519 (or update generated inventory)." >&2
  exit 1
}
echo "Local preflight passed."
