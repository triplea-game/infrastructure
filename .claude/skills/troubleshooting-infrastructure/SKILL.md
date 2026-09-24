---
name: troubleshooting-infrastructure
description: Diagnose and fix a TripleA production infrastructure outage in this fleet — lobby/support reverse-proxying, the /support/* and map-listing endpoints, oauth2 auth gate, and config drift from a hand-applied branch. Read-only diagnosis; fixes go through CI on main. Use for a lobby/support 502, "map listing down", or prod behaving unlike main.
---

# Troubleshooting TripleA infrastructure

Diagnose live fleet outages (usually lobby↔support). **Read-only first; fix via
CI on `main`.** The full manual — architecture, failure-mode table, the
config-drift lesson, forensics, and a worked example — is the source of truth in
the runbook:

`docs/runbooks/troubleshooting-infrastructure.md`

Read it before acting. The essentials, repeated so they always apply:

## Two rules

1. **Diagnose read-only.** Pull logs via the `debugging-triplea-production` skill
   (`pull-logs.sh`, the `read-only` account); use the forensic scripts here,
   which only read. Do not SSH in to mutate, restart, or edit as part of
   diagnosis.
2. **Fix through CI on `main`.** A fix is a code/infra change reviewed and
   deployed by the GitHub `infrastructure` workflow, which applies **only
   `main`**. Never leave a hand-applied branch live on prod — that is what has
   caused the outages (see the runbook's "Config drift").

## Happy path

```bash
# 1. Reproduce (answers in <5s or not at all — never wait 60s):
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' --max-time 5 \
  https://prod.triplea-game.org/support/maps/listing

# 2. Snapshot a host (read-only). Resolve IPs via ansible-inventory
#    (recipe in the debugging-triplea-production runbook):
ssh dan@<host-ip> 'sudo bash -s -- 30' < forensic-check.sh &> host-forensic.txt
ssh dan@<host-ip> 'sudo bash -s -- 30' < login-check.sh
```

Then work the runbook's failure-mode table. **If prod behaves unlike `main`,
suspect a branch hand-applied to prod and never reverted** — confirm with
`login-check.sh` (CI applies = the `ansible` account from Azure IPs; a manual
apply = an admin account with `become`), and fix by re-running the `main` deploy.

## Scripts (read-only)

- `forensic-check.sh [DAYS]` — full snapshot: logins by user/IP, nginx error-log
  timeline, recently-changed `/etc` & `/opt`, `nginx -T`, docker/cron/timers.
- `login-check.sh [DAYS]` — categorises SSH logins; flags admin (manual) applies
  vs the `ansible` CI account.
