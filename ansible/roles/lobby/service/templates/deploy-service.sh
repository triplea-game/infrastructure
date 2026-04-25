#!/bin/bash
# Managed by Ansible - do not edit manually
set -euo pipefail

docker pull ghcr.io/triplea-game/lobby/server:latest
systemctl restart triplea_lobby_server_2_7
