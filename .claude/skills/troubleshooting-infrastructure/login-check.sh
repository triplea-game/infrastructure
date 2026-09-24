#!/usr/bin/env bash
#
# login-check.sh — READ-ONLY: categorise SSH logins to tell a CI apply from a
# manual (human) apply. Run ON a fleet host as root:
#
#   ssh dan@<host-ip> 'sudo bash -s -- 30' < login-check.sh
#   (arg = days to look back; default 30)
#
# Why it matters: CI (the GitHub `infrastructure` workflow) applies as the
# `ansible` account from GitHub-runner (Azure) IPs. A MANUAL `ansible-playbook`
# / `just apply` from a workstation runs as an ADMIN account (e.g. `dan`) with
# `become` — its fingerprint is a `dan` login followed by sudo lines of the form
#   COMMAND=/bin/sh -c 'echo BECOME-SUCCESS-…; /usr/bin/python3'
# A manual apply of a non-main branch is how prod drifts from `main`.
# See docs/runbooks/troubleshooting-infrastructure.md ("Config drift").

DAYS="${1:-30}"
SINCE="-${DAYS}d"

logins() { journalctl _COMM=sshd --since "$SINCE" -o short-iso --no-pager 2>/dev/null; }

echo "===== $(hostname): SSH logins over the last ${DAYS} day(s) ====="

echo
echo "--- every accepted login (time . method . user . source IP) ---"
logins | grep -E 'Accepted ' || echo "(none)"

echo
echo "--- by USER  (service accounts = ansible/deploy = CI; admin accounts = manual) ---"
logins | grep -oE 'Accepted \w+ for \S+' | awk '{print $4}' | sort | uniq -c | sort -rn

echo
echo "--- by SOURCE IP  (Azure ranges = CI runners; anything else = investigate) ---"
logins | grep -E 'Accepted ' | grep -oE 'from [0-9a-fA-F.:]+' | awk '{print $2}' | sort | uniq -c | sort -rn

echo
echo "--- MANUAL-APPLY fingerprint: admin sudo 'become' (ansible run by a human) ---"
journalctl _COMM=sudo --since "$SINCE" -o short-iso --no-pager 2>/dev/null \
  | grep -E 'BECOME-SUCCESS.*python3' \
  | grep -vE ' ansible :' \
  | sed -E 's/(echo BECOME-SUCCESS-)[a-z]+/\1…/' \
  || echo "(none — no human-run ansible become detected)"

echo
echo "Tip: cross-check any admin apply timestamp against 'gh run list --workflow=infrastructure.yml'."
