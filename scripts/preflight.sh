#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tfvars_file="$repo_root/terraform/terraform.tfvars"

for command in terraform ansible-playbook jq ssh; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

test -f "$tfvars_file" || {
  echo "Missing terraform/terraform.tfvars. Copy terraform/terraform.tfvars.example and set local values." >&2
  exit 1
}

if grep -Eq '^[[:space:]]*ssh_public_key_path[[:space:]]*=' "$tfvars_file"; then
  echo "Remove obsolete ssh_public_key_path from terraform/terraform.tfvars; the image supplies SSH access." >&2
  exit 1
fi

echo "Local preflight passed."
