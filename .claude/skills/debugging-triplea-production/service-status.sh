#!/usr/bin/env bash
#
# service-status.sh — read-only production service status for TripleA bots.
#
# Sibling to pull-logs.sh with the same read-only safety model: it builds the
# remote command itself and connects as the low-privilege `read-only` account.
# `systemctl status` is an unprivileged read, and the account already reads
# journald via its systemd-journal membership, so this needs no sudo and no
# server-side grant. Capability changes here are a separate, reviewed task, not
# something to edit mid-debug.
#
# Read-only: only `systemctl --no-pager status <unit>` — never start/stop/
# restart. Bounded: the journal tail is line-capped. No passthrough: only an
# allowlisted bot resolves to a unit, and every value is %q-quoted so the remote
# shell cannot re-interpret it.

set -euo pipefail

# The read-only SSH account; overridable so an admin can point at their own
# (must be a read-only account — see roles/system/read_only_account).
readonly SSH_USER="${TRIPLEA_RO_USER:-read-only}"

# Private key for that account, pinned with IdentitiesOnly (below) so a loaded
# agent with other keys can't trip the server's MaxAuthTries.
readonly SSH_KEY="${TRIPLEA_RO_KEY:-$HOME/.ssh/triplea-read-only}"

usage() {
  echo "usage: service-status.sh <botN> <host> [--lines N]" >&2
  exit 2
}

# Resolve an allowlisted bot to its systemd unit. Scoped to bot units because
# they are systemd-native and readable without sudo; the docker-compose services
# (lobby/marti/support) and forums would need a `docker compose ps` sudo grant,
# which is a separate server-side decision.
resolve_unit() {
  case "$1" in
    bot[0-9]|bot[0-9][0-9]|bot[0-9][0-9][0-9])
             UNIT="${1/bot/bot@}.service" ;;
    *) echo "service-status: unsupported service '$1' (bots only: bot0-bot999)" >&2; exit 2 ;;
  esac
}

SERVICE="${1:-}"; HOST="${2:-}"
[[ -n "$SERVICE" && -n "$HOST" ]] || usage
shift 2

# The host is an ssh destination, not shell input; still, keep it to a plain
# hostname/IP so nothing odd reaches ssh.
[[ "$HOST" =~ ^[A-Za-z0-9._:-]+$ ]] || { echo "service-status: invalid host '$HOST'" >&2; exit 2; }

LINES=10
readonly MAX_LINES=200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lines) LINES="${2:?}"; shift 2 ;;
    *) echo "service-status: rejected argument '$1'" >&2; exit 2 ;;
  esac
done

[[ "$LINES" =~ ^[0-9]+$ ]] || { echo "service-status: --lines must be an integer" >&2; exit 2; }
(( LINES > MAX_LINES )) && LINES=$MAX_LINES

resolve_unit "$SERVICE"

# Build the remote command as a single quoted string; %q makes each value inert.
# -n caps the journal tail that status appends (read via the systemd-journal group).
build_remote() {
  local cmd=(systemctl --no-pager -n "$LINES" status "$UNIT")
  printf '%q ' "${cmd[@]}"
}

ssh_opts=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new)
[[ -f "$SSH_KEY" ]] && ssh_opts+=(-i "$SSH_KEY" -o IdentitiesOnly=yes)

# `systemctl status` exits non-zero when the unit is inactive or failed; the
# wrapper passes that code through, so a non-zero status here is a unit state,
# not a wrapper error.
exec ssh "${ssh_opts[@]}" "${SSH_USER}@${HOST}" "$(build_remote)"
