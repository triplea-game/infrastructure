#!/bin/bash

set -eu

scriptDir="$(dirname "$0")"

if [[ $1 == "--apply" ]]; then
  CHECK_MODE=""
 :
else
  CHECK_MODE="--check --diff"
  echo "!!! CHECK MODE, NO CHANGES WILL BE MADE !!!"
  echo "    To instead apply changes, run: $0 --apply"
  echo ""
 :
fi;

function main() {
  # Check if ansible is installed, if not, then ask to install it.
  hash ansible-playbook 2> /dev/null || installAnsible

  # run ansible
  set -x
  ANSIBLE_CONFIG="$scriptDir/ansible.cfg" \
  ansible-playbook \
    --inventory "$scriptDir/ansible/prod.inventory" \
    $CHECK_MODE "$scriptDir/ansible/playbook.yml"
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

