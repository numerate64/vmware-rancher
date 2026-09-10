#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_dir="$repo_root/terraform"
output_file="${INVENTORY_OUTPUT_PATH:-$repo_root/ansible/inventory/hosts.yml}"

command -v jq >/dev/null || { echo "jq is required." >&2; exit 1; }
nodes_json="$(terraform -chdir="$terraform_dir" output -json k3s_nodes)" || {
  echo "Terraform output k3s_nodes is unavailable. Run a successful terraform apply first." >&2
  exit 1
}

printf '%s\n' "$nodes_json" | jq -e '
  type == "array" and length == 3 and all(.[]; (.name | type == "string") and (.ip | type == "string") and (.ip | length > 0))
' >/dev/null || {
  echo "Terraform output k3s_nodes must contain three node names and DHCP addresses." >&2
  exit 1
}

temp_file="$(mktemp "${output_file}.tmp.XXXXXX")"
trap 'rm -f "$temp_file"' EXIT

{
  cat <<'YAML'
all:
  vars:
    ansible_user: ansible
    ansible_python_interpreter: /usr/bin/python3
  children:
    k3s_servers:
      hosts:
YAML
  printf '%s\n' "$nodes_json" | jq -r '.[] | "        \(.name): { ansible_host: \(.ip) }"'
} > "$temp_file"

mv "$temp_file" "$output_file"
trap - EXIT

echo "Wrote $output_file"
