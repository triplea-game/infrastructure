#!/bin/bash

# Previews (default) or, with APPLY=1, applies terraform and then ansible.
# Any args are passed to ansible-playbook, and terraform runs only when there
# are none: it has no equivalent of '--limit' or '--tags', so a scoped run would
# otherwise still plan or apply every server.
#
# Examples: ./run.sh
#           APPLY=1 ./run.sh --limit bots --tags system --verbose


set -eu

scriptDir="$(dirname "$0")"

function printCheckMode() {
  local args=""
  if [[ $# -gt 0 ]]; then
    printf -v args ' %q' "$@"
  fi
  echo ""
  echo "!!! PREVIEW MODE, NO CHANGES ARE ACTUALLY MADE !!!"
  echo "    To apply changes, instead run: APPLY=1 $0$args"
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
  printCheckMode "$@"
fi

if [[ $# -eq 0 ]]; then
  (
    set -x
    cd "$scriptDir/terraform"
    just "$tfRecipe"
  )
else
  echo "Arguments given: skipping terraform, running ansible only." >&2
fi

(
  set -x
  cd "$scriptDir/ansible"
  just "$ansibleRecipe" "$@"
)

if [[ "$tfRecipe" == "plan" ]]; then
  printCheckMode "$@"
fi
