#!/bin/bash
# Ansible vault password script.
# Ansible will execute this file and use stdout as the vault password.
# Requires the TRIPLEA_ANSIBLE_VAULT_PASSWORD environment variable to be set.
set -euo pipefail

if [[ -z "${TRIPLEA_ANSIBLE_VAULT_PASSWORD:-}" ]]; then
  echo "ERROR: TRIPLEA_ANSIBLE_VAULT_PASSWORD environment variable is not set" >&2
  exit 1
fi

echo "${TRIPLEA_ANSIBLE_VAULT_PASSWORD}"

