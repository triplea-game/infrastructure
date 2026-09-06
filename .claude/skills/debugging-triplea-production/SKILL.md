---
name: debugging-triplea-production
description: Safely pull and read logs from TripleA production servers (lobby, dice/marti, bots, forums, support) to diagnose a live issue. Read-only — fetch logs ONLY through the sanctioned pull-logs.sh wrapper; never SSH, restart, deploy, edit, or run any mutating command against production. Use when investigating a production outage, error report, or user-reported bug that needs real server logs.
---

# Debugging TripleA Production

Canonical home of this skill and its wrapper (a thin global skill of the same
name points here). You diagnose live issues by **reading logs**, only through the
wrapper, and you touch production no other way.

**Human operators:** the full manual — the safety model, targets, IP resolution,
prerequisites, workflow, and PII handling — is the source of truth in the runbook:
`docs/runbooks/debugging-triplea-production.md`.

## The two hard rules

1. **The only way you access a production server is by running a sanctioned
   wrapper** — `pull-logs.sh` (logs) or `service-status.sh` (bot `systemctl
   status`). Never run `ssh`, `journalctl`, `docker`, `psql`, `ansible`, or
   `terraform` against production directly — not to "just check," not because a
   flag is missing. If a wrapper can't get what you need, stop and tell the
   operator which flag is missing.
2. **Never modify the wrappers** as part of an investigation. They are reviewed,
   version-controlled tools; changing one is a separate, deliberate task. The hard
   safety gate is the read-only server account, which can do nothing but read logs
   and unit status; the wrappers are the sanctioned interface to it.

## Never (destructive / out of scope)

- Never restart, stop, redeploy, `docker compose up/down/pull/exec`, or otherwise
  change any service's state.
- Never edit files on a server, write to any database, or run migrations.
- Never run `ansible-playbook` / `terraform apply` (even check mode) while
  debugging.
- Never stream/follow logs — every fetch is line-capped.
- Never paste raw production logs into an external service, PR, or issue (they
  contain PII — user emails and IPs). Redact; raw excerpts go only to a local
  scratch dir.
- Never copy secrets, keys, `.env`, or `config.json` off a server.

## Invoke

Run from this directory: `./pull-logs.sh <service> <host> [flags]`. Valid
services: `lobby`, `marti`, `bot<N>` (eg `bot01`), `forums`, `support`. The SSH
user defaults to the `read-only` account. **Resolve the host IP first** — the
recipes are in the runbook ("Resolving the server address"); IP resolution needs
`LINODE_ACCESS_TOKEN`.

```
./pull-logs.sh lobby <lobby-ip> --since "2 hours ago" --grep ERROR --lines 500
```

Flags (all optional; the wrapper rejects anything else): `--since`, `--until`,
`--lines` (default 500, max 5000), `--grep` (fixed-string), `--priority`
(journald only). Time semantics differ by backend — journald (`bot*`, `forums`)
take `"2 hours ago"` / ISO; docker (`lobby`, `marti`, `support`) want `2h` /
RFC3339. See the runbook for targets, backends, and the full workflow.

## Service status (bots)

`./service-status.sh <botN> <host> [--lines N]` reports a bot's `systemctl
status` (active/failed, last exit, short journal tail) — read-only, same
`read-only` account, no start/stop/restart. Bots only. The argument is the
systemd instance (`bot@01`..`bot@03`), the same numbering `pull-logs.sh` uses —
not the lobby `BOT_NAME`: `Bot_503` is bot_number 5 + instance 03, ie
`./service-status.sh bot03 <server-5-ip>`. `--lines` caps the journal tail
(default 10, max 200).

## Workflow (short)

Confirm scope → fetch a bounded window (start narrow) → read, hypothesize,
adjust the window → report, redacting PII. You **diagnose**; you never fix in
production.
