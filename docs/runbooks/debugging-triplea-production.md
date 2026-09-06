# Runbook: Debugging TripleA production

How to pull and read logs from TripleA production servers to diagnose a live
issue, by hand. This is the human-operator manual; an AI agent follows the same
rules through the `debugging-triplea-production` skill, but everything an operator
needs to run the procedure themselves is here.

## The safety model — why this is read-only

You diagnose live issues by **reading logs only**, and only through the wrapper
`pull-logs.sh`. This is not merely a convention:

- The hard safety gate is the **`read-only` server account** the wrapper connects
  as. That account can do nothing but read logs — journald read via group
  membership plus a narrow `docker compose … logs` sudoers rule. Even a mistake
  cannot mutate a server, because the account has no capability to.
- The wrapper is the sanctioned, ergonomic interface to that account. It builds
  every remote command itself and accepts only a fixed set of parameters; you
  supply nothing free-form.

Because of that gate, diagnosis never touches production any other way. You do
**not** fix in production — a fix is a code or infra change that goes through the
normal review and deploy path.

### Never (destructive / out of scope)

- Never restart, stop, start, redeploy, `docker compose up/down/pull/exec`, or
  otherwise change any service's state.
- Never edit files on a server, write to any database, or run migrations.
- Never run `ansible-playbook` / `terraform apply` (even check mode) while
  debugging.
- Never stream or follow logs — every fetch is line-capped.
- Never paste raw production logs into an external service, PR, or issue. Logs
  contain user emails and IPs (PII); summarize and redact. Raw excerpts go only
  to a local scratch dir, never a repo or external service.
- Never copy secrets, keys, `.env`, or `config.json` off a server.

## Prerequisites

The wrapper runs directly from the checkout — no install, no root ownership, no
config. It never mutates anything, and the real safety gate is the server-side
account, so there is nothing to lock down locally.

The `read-only` account is provisioned by Ansible — see
`roles/system/read_only_account/` (defined under `read_only_user` in
`ansible/group_vars/all.yml`). The wrapper connects as it by default; point it at
a different read-only account with `TRIPLEA_RO_USER`. Its key is offered by
`ssh-agent` or an `IdentityFile` in your `~/.ssh/config`.

Resolving IPs (below) needs `LINODE_ACCESS_TOKEN`. If it is not set, get it before
starting rather than guessing an address.

## Targets and where their logs live

| Target | Log source the wrapper reads |
|---|---|
| `lobby` | `docker compose logs` — `/opt/lobby`, service `service` |
| `marti` (dice server) | `docker compose logs` — `/opt/triplea-marti`, service `app` |
| `bot<N>` (eg `bot01`) | journald — unit `bot@<N>` |
| `forums` | journald — tag `forums-nodebb` |
| `support` | `docker compose logs` — `/opt/support` (maps/support server) |

Servers are Linode instances discovered by tag; the inventory is
`ansible/inventory/linode.yml`.

## Running the wrapper

Run it straight from the skill directory (`./pull-logs.sh`, or its full path).
The shape is `<service> <host> [flags]`. The SSH user defaults to the `read-only`
account (override with `TRIPLEA_RO_USER`); resolve the host IP first (next
section).

```
./pull-logs.sh lobby  <lobby-ip>  --since "2 hours ago" --lines 500
./pull-logs.sh marti  <marti-ip>  --since "2026-09-04 14:00" --until "2026-09-04 15:00"
./pull-logs.sh bot01  <bot-ip>    --since "30 min ago" --grep ERROR
./pull-logs.sh forums <forums-ip> --lines 200 --priority err
```

Flags (all optional; the wrapper rejects anything not on this list):

| Flag | Meaning |
|---|---|
| `--since <when>` | Start time (`"2 hours ago"`, ISO timestamp). |
| `--until <when>` | End time. |
| `--lines <N>` | Cap on lines (default 500, hard max 5000). |
| `--grep <pattern>` | Server-side fixed-string filter (safely quoted). |
| `--priority <p>` | Minimum severity (journald only; ignored for docker targets). |

`--since` / `--until` semantics differ by backend: journald services (`bot*`,
`forums`) take `"2 hours ago"` or ISO timestamps; docker services (`lobby`,
`marti`, `support`) want `2h` / `10m` / RFC3339. There is intentionally no
`--follow`, no free-form passthrough, and no way to change a target's working
directory or service name.

## Resolving the server address

IPs are dynamic on Linode, so nothing static is stored — resolve the current IP
from the dynamic inventory at debug time. Run these from the repo's `ansible/`
directory. Start with the overview (groups, hosts, each host's `ansible_host` =
public IP, and bot tags):

```
ansible-inventory -i inventory/linode.yml --graph --vars
```

The `--list` JSON wraps values as `{"__ansible_unsafe": "..."}`, so the `jq`
below unwraps them with a small `raw` helper — keep it when adapting.

### Single-server services (lobby, marti, forums, support)

Each is one server in its own Linode-tag group (group name = the tag; confirm
with `--graph`). Pull its IP directly:

```
ansible-inventory -i inventory/linode.yml --list | jq -r '
  def raw: if type=="object" then .__ansible_unsafe else . end;
  .lobby.hosts[0] as $h | ._meta.hostvars[$h].ansible_host | raw'
```

### Bots (resolve by BOT_NAME, eg `Bot_401_London`)

There are several bot servers (one per location), each tagged `botnum-<n>` +
`botlocation-<loc>`; the inventory exposes these as `bot_number` / `bot_location`.
Each server runs instances `bot@01`, `bot@02`, … A `BOT_NAME` is
`Bot_<bot_number><instance>_<location>`, so `Bot_401_London` = location `London`,
and `401` = bot_number `4` + instance `01`. To resolve:

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

If a location has more than one bot server (different `bot_number`s), match on the
`bot_number` that prefixes the middle digits, not on location alone. Then pass the
resolved IP as the `<host>` argument to the wrapper.

## Checking service status (bots)

Alongside logs, `service-status.sh` reports a bot's `systemctl status` — whether
the unit is active, its last exit, and a short journal tail — read-only, through
the same `read-only` account, with no start/stop/restart path:

```
./service-status.sh bot03 <bot-ip> --lines 20
```

The argument is the **systemd instance** (`bot@01`..`bot@03`), the same numbering
`pull-logs.sh` uses — not the lobby `BOT_NAME`. Decompose a name first, exactly as
above: `Bot_503` is bot_number 5 + instance 03, so it is `bot@03` on bot_number
5's server — `./service-status.sh bot03 <server-5-ip>`. `--lines` caps the journal
tail (default 10, max 200). Status reads without sudo — the account's
systemd-journal membership already covers the journal tail — so it needs no
server-side grant beyond the existing read-only account.

Only bots are supported: the docker-compose services (lobby, marti, support) and
forums have no per-instance systemd unit, and `docker compose ps` would need its
own sudoers grant — a separate, deliberate change.

## Investigation workflow

1. Confirm scope: which service, what symptom, what time window.
2. Fetch a bounded window — start narrow (`--since` + `--grep`).
3. Read, hypothesize, then widen or narrow the window — always via the wrapper.
4. Report findings. Raw excerpts go to a local scratch dir only; redact PII in
   anything you surface.
5. You diagnose; you do not fix in production.

## If the wrapper is unavailable

The wrapper is only the ergonomic interface; the real gate is the `read-only`
account. If the script itself is missing or broken, you can still read logs by
connecting **as the `read-only` account** and running the same read-only commands
it would (`docker compose … logs` for docker targets, `journalctl` for journald
targets) — but never as a privileged account, and never a mutating command. Do
not "fix" `pull-logs.sh` mid-investigation; repairing it is a separate, reviewed
task.
