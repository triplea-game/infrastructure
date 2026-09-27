#!/bin/bash

# This script is a wrapper around 'ansible-playbook'
# When run without any args, ansible is run in 'dry-run' mode and will not make any changes.
# Any args passed into this script are passed directly to the ansible-playbook command.
#
# Examples: ./run.sh --limit bot --tags system --verbose


set -eu

scriptDir="$(dirname "$0")"

function printCheckMode() {
  echo ""
  echo "!!! PREVIEW MODE, NO CHANGES ARE ACTUALLY MADE !!!"
  echo "    To apply changes, instead run: APPLY=1 $0"
}

if ! hash ansible-playbook 2> /dev/null; then
  echo "ansible-playbook not found; install it with: (cd $scriptDir/ansible && just install-ansible)" >&2
  exit 1
fi

# Only an exact APPLY=1 applies; any other value (APPLY=0, APPLY=no) previews.
if [[ "${APPLY-}" == 1 ]]; then
  tfRecipe="apply"
  ansibleRecipe="apply"
else
  tfRecipe="plan"
  ansibleRecipe="diff"
  printCheckMode
fi

(
  set -x
  cd "$scriptDir/terraform"
  just "$tfRecipe"
)

(
  set -x
  cd "$scriptDir/ansible"
  just "$ansibleRecipe"
)

if [[ "$tfRecipe" == "plan" ]]; then
  printCheckMode
fi
