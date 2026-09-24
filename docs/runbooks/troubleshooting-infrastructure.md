# Runbook: Troubleshooting TripleA infrastructure

How to diagnose and fix a TripleA production outage in this fleet — most often a
lobby/support failure such as "the map listing is down". This is the
human-operator manual; an AI agent follows the same steps through the
`troubleshooting-infrastructure` skill.

Read-only diagnosis first (via the `debugging-triplea-production` skill /
`pull-logs.sh`, and the forensic scripts beside the skill). **Fixes go through
CI on `main`** — see "Config drift" below for why that matters more than it looks.

## How support is reached (the architecture you're debugging)

The public site is `prod.triplea-game.org`, served by **nginx on the lobby
host**. Support runs on its **own** Linode and is reached over the
**same-datacentre private network**:

```
game client ─https─> lobby nginx (prod.triplea-game.org)
                        │  /support/*  ─> auth_request to oauth2-proxy (lobby, 127.0.0.1:4180)
                        │              ─> proxy_pass http://support_backend
                        └─ support_backend = <support private_ip>:8010  (private net, plaintext)
                                              └─> support container publishes {{ private_ip }}:8010
```

Key facts, each a place things break:

- **Lobby nginx → support is private + plaintext + port 8010**, defined in
  `/etc/nginx/include/pre-server-support.conf` (`upstream support_backend { server <priv>:8010; }`)
  and `server-support.conf` (`proxy_pass http://support_backend`). Rendered by the
  `support/nginx_conf` role from `hostvars[support].private_ip`.
- **Every `/support/*` request first hits an `auth_request`** to oauth2-proxy on
  the lobby host at `127.0.0.1:4180`. Anonymous requests get 401 and fall through
  to `@optional_anon`, so **public** pages (the map listing, `latest-version`)
  still work — *unless oauth2-proxy is down*, in which case the subrequest fails
  and even public `/support/*` returns 502.
- **The support container publishes 8010 on its private IP** (`{{ private_ip }}:8010:8010`
  in `/opt/support/docker-compose.yml`), **not** loopback or `0.0.0.0`. A
  `DOCKER-USER` iptables rule on the support box allows only lobby's private IP to
  reach 8010.
- The client path for the map listing is `GET /support/maps/listing`
  (`ServerPaths.MAPS_LISTING_PATH` in the game repo). nginx forwards the URI
  unchanged, so support serves it at `/support/maps/listing`.

## Quick triage

```bash
# The public endpoint. It answers in <5s or not at all — never wait 60s.
curl -sS -o /dev/null -w '%{http_code}  %{time_total}s\n' --max-time 5 \
  https://prod.triplea-game.org/support/maps/listing
```

- **200** — healthy (payload is `{"maps":[...]}`, ~300 maps).
- **502 fast (<1s)** — upstream actively refused (nothing listening) or nginx has
  marked the upstream down.
- **502 after ~60s** — packets are being **dropped/blackholed** (missing IP or a
  firewall DROP), not refused.
- **000 / timeout** — a connect that hangs.

Isolate nginx-vs-backend: from the **lobby** box, hit the backend directly. If
this is fast 200 but the public URL 502s, the fault is on lobby's nginx side, not
support.

```bash
curl -m 5 -sS -o /dev/null -w '%{http_code} %{time_total}s\n' \
  http://<support private_ip>:8010/support/maps/listing
```

nginx errors on lobby are in `/var/log/nginx/error.log` (**not** journald — the
log wrapper won't show them). The `upstream: "..."` field names exactly what
nginx dialed — trust it.

## Failure modes (symptom → check → fix)

| # | Symptom | Check | Fix |
|---|---------|-------|-----|
| 1 | lobby nginx dials the **wrong target** (e.g. `https://<public ip>:443`, or a stale private IP) | `sudo nginx -T` on lobby; `grep -r support_backend /etc/nginx/`. The `upstream:` in the error log is the tell. | **Redeploy `main` via CI.** The templates are private/8010/http; a wrong target means the box drifted from `main` — see "Config drift". |
| 2 | support container **up but 8010 not published** on the private IP (bound to `127.0.0.1` or missing) | On support: `docker ps` PORTS column; from the box `curl http://<priv>:8010/q/health/ready` (instant refuse = not published) | Correct `/opt/support/docker-compose.yml` port to `<priv>:8010:8010`; `docker compose up -d`. Then redeploy `main` to make it stick. |
| 3 | 502 on **all** `/support/*`, 60s-ish | oauth2-proxy on lobby: `curl -m5 http://127.0.0.1:4180/ping` (expect 200); `systemctl status oauth2-proxy` | `sudo systemctl restart oauth2-proxy` |
| 4 | lobby's traffic **dropped** at support's firewall | On support: `sudo iptables -L DOCKER-USER -n -v` — is lobby's private IP RETURN'd before the DROP? are DROP counters climbing? | Redeploy `support/service` (renders the rule from inventory) |
| 5 | support **private IP** absent | On support: `ip addr show eth0 \| grep 192.168` | `sudo ip addr add <priv>/17 dev eth0` — **but** this has *not* historically been the real cause; don't stop here. See below. |

**Do not assume "the private IP fell off."** Every incident so far blamed on a
dropping private IP turned out to be something else (a hand-applied branch, a
loopback port binding). Verify with `ip addr` before spending time on it.

## Config drift — the failure mode that has actually bitten us

**CI (`.github/workflows/infrastructure.yml`) applies only `main`**, only on push
or `workflow_dispatch` **to `main`**, connecting as the **`ansible`** account from
GitHub-runner (Azure) IPs. `workflow_dispatch` on a branch and PR events **do not
apply** (they diff/plan only).

Therefore the only way prod runs anything other than `main` is a **manual
`ansible-playbook` / `just apply` from a feature-branch checkout**, run as an
**admin account (`dan`) with `become`**. That is invisible to CI, and because CI
only ever reconciles `main`, prod then **silently diverges from `main`** until
something breaks.

**If prod behaves unlike `main`, suspect a hand-applied branch that was never
reverted.** Confirm it with `login-check.sh` (below): CI applies show as the
`ansible` account from Azure IPs; a manual apply shows as an admin account
(`dan`) with the `echo BECOME-SUCCESS-…; /usr/bin/python3` sudo signature.

**Fix pattern:** re-run the **`main`** infra deploy (it converges every host back
to `main`), then **delete or finish** the stray branch so it can't be re-applied.

## Forensics (read-only)

Two scripts live beside the skill
(`.claude/skills/troubleshooting-infrastructure/`). Run them from your
workstation against a host IP (resolve IPs with `ansible-inventory` — recipe in
the `debugging-triplea-production` runbook):

```bash
# Full snapshot: logins by user/IP, nginx error-log timeline, recently-changed
# /etc & /opt files, nginx -T, docker/cron/timers, apt history.
ssh dan@<host-ip> 'sudo bash -s -- 30' < .../forensic-check.sh &> host-forensic.txt

# Just "who applied what": categorises SSH logins; flags admin (manual) applies.
ssh dan@<host-ip> 'sudo bash -s -- 30' < .../login-check.sh
```

What to read first: the **nginx error-log timeline** (when did the bad upstream
start?), **recently-modified `/etc`** (which config changed and exactly when),
and the **login summary** (was there an admin-account apply near that time?).

## Worked example — 2026-09-24 map-listing outage

`/support/maps/listing` returned 502. Chain, in the order it was peeled back:
support's compose was bound to `127.0.0.1:8010` (not the private IP); once fixed,
lobby still 502'd because **lobby's nginx was dialing `https://<support public
ip>:443`** — the design from the unmerged `feat/support-public-dns` branch.
Forensics showed that branch had been **hand-applied to prod from an admin
workstation ~2026-09-21 and left incomplete** (never reverted, never merged); CI
only applies `main`, so the divergence stayed invisible for days. Fix: re-run the
`main` infra deploy, which restored the private-network design. Root cause was an
unfinished manual apply — **not** a private-IP problem at any point.

## Safety

- Diagnose read-only: logs via `debugging-triplea-production`/`pull-logs.sh` as
  the `read-only` account; the forensic scripts here only read.
- Fixes are code/infra changes that go through **review + CI on `main`**. Do not
  hand-apply a branch to prod; if you must, revert it before you end the session.
