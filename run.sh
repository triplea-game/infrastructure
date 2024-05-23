#!/bin/bash

set -eu

scriptDir="$(dirname "$0")"


function main() {
  # Check if ansible is installed, if not, then ask to install it.
  hash ansible-playbook 2> /dev/null || installAnsible

  if [[ "${1-}" == "--apply" ]]; then
    local CHECK_MODE=""
    runAnsible "$CHECK_MODE"
  else
    local CHECK_MODE="--check --diff"
    printCheckMode
    runAnsible "$CHECK_MODE"
    printCheckMode
  fi
}

function runAnsible() {
  local CHECK_MODE=${1-}
  # run ansible
  set -x
  # shellcheck disable=SC2086
  ANSIBLE_CONFIG="$scriptDir/ansible.cfg" \
    ansible-playbook \
      --verbose \
      --inventory "$scriptDir/ansible/prod.inventory" \
      $CHECK_MODE "$scriptDir/ansible/playbook.yml"
  set +x
}

function installAnsible() {
  read -p "Ansible not installed, would you like to install it now with apt (y/n)? " -n 1 -r
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

function printCheckMode() {
    echo ""
    echo "!!! PREVIEW MODE, NO CHANGES ARE ACTUALLY MADE !!!"
    echo "    To apply changes, instead run: $0 --apply"
    echo ""
}

main "${1-}"
