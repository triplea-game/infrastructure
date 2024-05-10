#!/bin/bash

set -eu

scriptDir="$(dirname "$0")"
source "$scriptDir/.bash/function.sh"

function main() {
  # Check if ansible is installed, if not, then ask to install it.
  hash ansible-playbook 2> /dev/null || installAnsible

  # run ansible
  set -x
  ANSIBLE_CONFIG="$scriptDir/ansible.cfg" ansible-playbook \
     --inventory "$scriptDir/ansible/inventory/production" \
     --vault-password-file $rootDir/infrastructure/vault_password \
     "$scriptDir/ansible/site.yml"
  #   $VAULT_PASSWORD_FILE_ARG $TAGS_ARG $DIFF_ARG $VERBOSE_ARG
  set +x
}

main

