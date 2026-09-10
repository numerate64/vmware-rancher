#!/usr/bin/env bash
# Installs the local Terraform + Ansible control-host prerequisites on Ubuntu 24.04.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  sudo -v
fi

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

source /etc/os-release
[[ "${ID}" == "ubuntu" ]] || fail "This installer supports Ubuntu only (detected: ${ID})."
[[ -n "${VERSION_CODENAME:-}" ]] || fail "Could not determine the Ubuntu release codename."

run_root apt-get update
run_root apt-get install -y \
  ansible \
  ca-certificates \
  curl \
  git \
  gnupg \
  jq \
  openssh-client \
  openssl \
  python3

keyring=/etc/apt/keyrings/hashicorp-archive-keyring.gpg
repository_file=/etc/apt/sources.list.d/hashicorp.list

run_root install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | run_root tee "${keyring}" >/dev/null
run_root chmod 0644 "${keyring}"
printf 'deb [signed-by=%s] https://apt.releases.hashicorp.com %s main\n' \
  "${keyring}" "${VERSION_CODENAME}" | run_root tee "${repository_file}" >/dev/null

run_root apt-get update
run_root apt-get install -y terraform

for command in terraform ansible-playbook ansible-galaxy jq ssh git curl openssl python3; do
  command -v "${command}" >/dev/null || fail "Expected command was not installed: ${command}"
done

terraform_version="$(terraform version -json | jq -r '.terraform_version')"
dpkg --compare-versions "${terraform_version}" ge 1.6.0 || \
  fail "Terraform ${terraform_version} is below the required version 1.6.0."

echo "Prerequisites installed successfully."
echo "Terraform: ${terraform_version}"
echo "Ansible: $(ansible-playbook --version | sed -n '1p')"
