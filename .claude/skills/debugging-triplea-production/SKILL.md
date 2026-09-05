---
name: debugging-triplea-production
description: Safely pull and read logs from TripleA production servers (lobby, dice/marti, bots, forums, support) to diagnose a live issue. Read-only — fetch logs ONLY through the sanctioned pull-logs.sh wrapper; never SSH, restart, deploy, edit, or run any mutating command against production. Use when investigating a production outage, error report, or user-reported bug that needs real server logs.
---

# Debugging TripleA Production

Canonical home of this skill and its wrapper. Because a repo-nested skill
does not auto-load, a thin global skill of the same name points here; the
rules and the script below are the source of truth.

You diagnose live TripleA production issues by **reading logs**, and you do
that **only** through the wrapper. You touch production no other way.

## The two hard rules

1. **The only way you access a production server is by running the wrapper**
   (`pull-logs.sh`). Never run `ssh`, `journalctl`, `docker`, `psql`,
   `ansible`, or `terraform` against production directly — not to "just
   check," not because a flag is missing. If the wrapper can't get what you
   need, stop and tell the operator which flag is missing.
2. **Never modify `pull-logs.sh`** as part of an investigation. It is a
   reviewed, version-controlled tool; changing it is a separate, deliberate,
   reviewed task — never something you do mid-debug. (The hard safety gate is
   the read-only server account, which can do nothing but read logs; the
   wrapper is the sanctioned, ergonomic interface to it.)

The wrapper is read-only by construction: it can fetch logs and nothing else.
It builds every remote command itself; you supply only the parameters below.

## Never (destructive / out of scope)

- Never restart, stop, start, redeploy, `docker compose up/down/pull/exec`,
  or otherwise change any service's state.
- Never edit files on a server, write to any database, or run migrations.
- Never run `ansible-playbook` / `terraform apply` (even check mode) while
  debugging.
- Never stream/follow logs — every fetch is line-capped.
- Never paste raw production logs into an external service, PR, or issue.
  Logs contain user emails and IPs (PII): summarize and redact; raw excerpts
  go only to a local scratch dir, never a repo or external service.
- Never copy secrets, keys, `.env`, or `config.json` off a server.

## Targets and where their logs live

| Target | Log source the wrapper uses |
|---|---|
| `lobby` | `docker compose logs` — `/opt/lobby`, service `service` |
| `marti` (dice server) | `docker compose logs` — `/opt/triplea-marti`, service `app` |
| `bot<N>` (e.g. `bot0`) | journald — unit `bot@<N>` |
| `forums` | journald — tag `forums-nodebb` |
| `support` | `docker compose logs` — `/opt/support` |

Servers are Linode instances discovered by tag; see the infrastructure repo
`ansible/inventory/linode.yml`.

## Usage

Run the wrapper straight from this directory (`./pull-logs.sh`, or its full
path). The shape is `<service> <host> [flags]`. The SSH user defaults to the
`read-only` account (override with `TRIPLEA_RO_USER`); the host is passed in —
resolve the current IP first (see "Resolving the server address" below).

```
./pull-logs.sh lobby  <lobby-ip>  --since "2 hours ago" --lines 500
./pull-logs.sh marti  <marti-ip>  --since "2026-09-04 14:00" --until "2026-09-04 15:00"
./pull-logs.sh bot01  <bot-ip>    --since "30 min ago" --grep ERROR
./pull-logs.sh forums <forums-ip> --lines 200 --priority err
```

Note: `--since`/`--until` semantics differ by backend — journald services
(`bot*`, `forums`) take `"2 hours ago"` / ISO timestamps; docker services
(`lobby`, `marti`, `support`) want `2h` / `10m` / RFC3339.

Options (all optional; the wrapper rejects anything not on this list):

| Flag | Meaning |
|---|---|
| `--since <when>` | Start time (`"2 hours ago"`, ISO timestamp). |
| `--until <when>` | End time. |
| `--lines <N>` | Cap on lines (default 500, hard max 5000). |
| `--grep <pattern>` | Server-side fixed-string filter (safely quoted). |
| `--priority <p>` | Minimum severity (journald only; ignored for docker targets). |

There is intentionally **no** `--follow`, no free-form passthrough, and no way
to change a target's working directory or service name.

## Prerequisites

The wrapper runs directly from the checkout — no install, no root ownership,
zero config. It never mutates anything, and the real safety gate is the
server-side account, so there's nothing to lock down locally.

The `read-only` account (journald read via group membership + a narrow
`docker compose … logs` sudoers rule) is provisioned by ansible — see
`roles/system/read_only_account/` (defined under `read_only_user` in
`ansible/group_vars/all.yml`). The wrapper connects as that account by default;
point it at a different read-only account with `TRIPLEA_RO_USER`. Its key is
offered by `ssh-agent` or an `IdentityFile` in the operator's `~/.ssh/config`.

## Resolving the server address

IPs are dynamic (Linode), so nothing static is stored — resolve the current IP
from the dynamic inventory at debug time. All of the below need
`LINODE_ACCESS_TOKEN`; if it isn't set, ask the operator rather than guessing
an address. Run these from the repo's `ansible/` directory. Start here to see
everything (groups, hosts, and each host's `ansible_host` = public IP, plus
bot tags):

```
ansible-inventory -i inventory/linode.yml --graph --vars
```

The `--list` JSON wraps values as `{"__ansible_unsafe": "..."}`, so the `jq`
below unwraps with a small `raw` helper — keep it when adapting.

### Single-server services (lobby, marti, forums, support)

Each is one server in its own Linode-tag group. `support` is the maps/support
server. Pull its IP directly (group name = the tag; confirm with `--graph`):

```
ansible-inventory -i inventory/linode.yml --list | jq -r '
  def raw: if type=="object" then .__ansible_unsafe else . end;
  .lobby.hosts[0] as $h | ._meta.hostvars[$h].ansible_host | raw'
```

### Bots (resolve by BOT_NAME, e.g. `Bot_401_London`)

There are several bot servers (one per location), each tagged `botnum-<n>` +
`botlocation-<loc>`; the inventory exposes these as `bot_number` /
`bot_location`. Each server runs instances `bot@01`, `bot@02`, … A `BOT_NAME`
is `Bot_<bot_number><instance>_<location>`, so `Bot_401_London` = location
`London`, and `401` = bot_number `4` + instance `01`. To resolve:

```
# 1. Get that location's server IP and bot_number:
ansible-inventory -i inventory/linode.yml --list | jq -r '
  def raw: if type=="object" then .__ansible_unsafe else . end;
  ._meta.hostvars | to_entries[]
  | select((.value.bot_location|raw)=="London")
  | "ip=\(.value.ansible_host|raw) bot_number=\(.value.bot_number|raw)"'
# 2. Strip the bot_number off the middle digits to get the instance:
#    "401" - bot_number 4 -> instance "01"   (keep leading zeros!)
# 3. Fetch:
./pull-logs.sh bot01 <ip> --since "30 min ago"
```

If a location has more than one bot server (different `bot_number`s), match on
the `bot_number` that prefixes the middle digits, not location alone.

Then pass the resolved IP as the `<host>` argument to the wrapper.

## Workflow for a production investigation

1. Confirm scope with the operator: which service, what symptom, what time window.
2. Fetch a bounded window (start narrow: `--since` + `--grep`).
3. Read, hypothesize, widen/narrow the window — always via the wrapper.
4. Report findings. Raw excerpts → a local scratch dir only; redact PII in
   anything you surface.
5. You **diagnose**; you do not fix in production. A fix is a code/infra
   change that goes through the normal review + deploy path.
