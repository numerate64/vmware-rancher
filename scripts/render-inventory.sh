#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_dir="$repo_root/terraform"
output_file="$repo_root/ansible/inventory/hosts.yml"

command -v jq >/dev/null || { echo "jq is required." >&2; exit 1; }
terraform -chdir="$terraform_dir" output -json k3s_nodes | jq -r '
  .[] | "        \(.name): { ansible_host: \(.ip) }"
' | {
  cat <<'YAML'
all:
  vars:
    ansible_user: ansible
    # Local-only private key; this file is ignored by Git.
    ansible_ssh_private_key_file: ~/.ssh/aqtech-rancher_ed25519
  children:
    k3s_servers:
      hosts:
YAML
  cat
} > "$output_file"

echo "Wrote $output_file"
