#!/usr/bin/env bash
#
# pull-logs.sh — read-only production log fetcher for TripleA.
#
# This is the sanctioned way to read TripleA production logs. It builds every
# remote command itself; the caller supplies only the service, the host, and
# the constrained flags parsed below. It never mutates a server. Agents must
# not edit it as part of a debug session; the real safety gate, though, is the
# read-only server account it connects as (it can do nothing but read logs).
#
# Guarantees:
#   - Read-only: only `journalctl` (read).
#   - Bounded: always line-capped; no --follow / streaming.
#   - No passthrough: unknown flags are rejected; --grep is fixed-string;
#     every caller value is passed as a distinct, %q-quoted argv element so
#     the remote shell cannot re-interpret it.
#
# Access: always SSHes as the low-privilege `read-only` account. The host
# is passed in (IPs are dynamic — resolve the current one from the Linode
# inventory; see SKILL.md). Every target reads the host journal, which the
# account can do via its adm/systemd-journal group membership — no sudo. The
# docker-compose services (lobby/marti/support) log to journald under a stable
# syslog tag, so their history survives container recreation and reads the same
# way as the bots and forums.

set -euo pipefail

# The read-only SSH account. Overridable so any admin can point at their own
# (must be a read-only account — see infrastructure roles/system/read_only_account).
readonly SSH_USER="${TRIPLEA_RO_USER:-read-only}"

# Private key for that account. Pinned with IdentitiesOnly so a loaded agent
# with other keys can't trip the server's MaxAuthTries. Convention default;
# override with TRIPLEA_RO_KEY. If the file is absent, fall back to agent/config.
readonly SSH_KEY="${TRIPLEA_RO_KEY:-$HOME/.ssh/triplea-read-only}"

usage() {
  echo "usage: pull-logs.sh <lobby|marti|support|forums|botN> <host> [--since W] [--until W] [--lines N] [--grep P] [--priority P]" >&2
  exit 2
}

# Resolve service -> journalctl selector (SELECTOR array). The docker-compose
# services log to journald under a stable tag set in their compose files; forums
# under its own tag; bots are systemd units.
resolve_service() {
  case "$1" in
    lobby)   SELECTOR=(-t lobby) ;;
    marti)   SELECTOR=(-t marti) ;;
    support) SELECTOR=(-t support) ;;
    forums)  SELECTOR=(-t forums-nodebb) ;;
    bot[0-9]|bot[0-9][0-9])
             SELECTOR=(-u "${1/bot/bot@}") ;;
    *) echo "pull-logs: unknown service '$1'" >&2; exit 2 ;;
  esac
}

SERVICE="${1:-}"; HOST="${2:-}"
[[ -n "$SERVICE" && -n "$HOST" ]] || usage
shift 2

# The host is an ssh destination, not shell input; still, keep it to a plain
# hostname/IP so nothing odd reaches ssh.
[[ "$HOST" =~ ^[A-Za-z0-9._:-]+$ ]] || { echo "pull-logs: invalid host '$HOST'" >&2; exit 2; }

SINCE="" UNTIL="" LINES=500 GREP="" PRIORITY=""
readonly MAX_LINES=5000

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)    SINCE="${2:?}"; shift 2 ;;
    --until)    UNTIL="${2:?}"; shift 2 ;;
    --lines)    LINES="${2:?}"; shift 2 ;;
    --grep)     GREP="${2:?}";  shift 2 ;;
    --priority) PRIORITY="${2:?}"; shift 2 ;;
    *) echo "pull-logs: rejected argument '$1'" >&2; exit 2 ;;
  esac
done

[[ "$LINES" =~ ^[0-9]+$ ]] || { echo "pull-logs: --lines must be an integer" >&2; exit 2; }
(( LINES > MAX_LINES )) && LINES=$MAX_LINES
if [[ -n "$PRIORITY" ]]; then
  case "$PRIORITY" in emerg|alert|crit|err|warning|notice|info|debug) ;; *)
    echo "pull-logs: invalid --priority '$PRIORITY'" >&2; exit 2 ;; esac
fi

resolve_service "$SERVICE"

# Build the remote command as a single quoted string; %q makes each value inert.
build_remote() {
  # read-only reads journald via the adm/systemd-journal group (no sudo).
  local cmd=(journalctl --no-pager -n "$LINES" "${SELECTOR[@]}")
  [[ -n "$SINCE" ]]    && cmd+=(--since "$SINCE")
  [[ -n "$UNTIL" ]]    && cmd+=(--until "$UNTIL")
  [[ -n "$PRIORITY" ]] && cmd+=(-p "$PRIORITY")
  printf '%q ' "${cmd[@]}"
  [[ -n "$GREP" ]] && { printf '| grep -F -- '; printf '%q' "$GREP"; }
}

ssh_opts=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new)
[[ -f "$SSH_KEY" ]] && ssh_opts+=(-i "$SSH_KEY" -o IdentitiesOnly=yes)

exec ssh "${ssh_opts[@]}" "${SSH_USER}@${HOST}" "$(build_remote)"
