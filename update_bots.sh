#!/bin/bash

# This script will download all maps to all bots.
set -eu

scriptDir="$(dirname "$0")"

set -x
ANSIBLE_CONFIG="$scriptDir/ansible.cfg" ansible \
  botHosts -a '/home/admin/download-all-maps' \
  --inventory "$scriptDir/ansible/prod.inventory" \
  --verbose

set +x
