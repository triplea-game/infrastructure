#!/bin/bash

set -eu

scriptDir="$(dirname "$0")"

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

function installAnsible() {
  read -p "Ansible not installed, would you like to install it now with apt? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    # Install steps from:
    # https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html
    sudo apt update
    sudo apt install software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt install --yes ansible
  else
    exit
  fi
}

main

