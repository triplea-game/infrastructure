#!/bin/bash

# This script will download all maps to all bots.
set -eu

(
  set -x
  cd "$(dirname "$0")/ansible"
  make update-bots
)
