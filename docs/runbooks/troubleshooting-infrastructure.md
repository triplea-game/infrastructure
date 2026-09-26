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
host**. Support runs on its **own** Linode, reached over **public DNS + TLS**
at `support.triplea-game.org`:

```
game client ─https─> lobby nginx (prod.triplea-game.org)
                        │  /support/*  ─> auth_request to oauth2-proxy (lobby, 127.0.0.1:4180)
                        │              ─> proxy_pass https://support_backend
                        └─ support_backend = support.triplea-game.org:443  (public DNS, TLS, cert verified)
                                              └─> support nginx (Let's Encrypt) ─> 127.0.0.1:8010 container
```

Key facts, each a place things break:

- **Lobby nginx → support is `https://support.triplea-game.org:443`**, defined in
  `/etc/nginx/include/pre-server-support.conf` (`upstream support_backend { server support.triplea-game.org:443; }`)
  and `server-support.conf` (`proxy_pass https://support_backend`, with
  `proxy_ssl_verify on`). Rendered by the `support/nginx_conf` role from
  `support_hostname` in `group_vars/all.yml`.
- **The name is resolved when lobby's nginx loads its config**, to both the A
  and AAAA records. If support is rebuilt (new IP), update DNS (managed outside
  this repo) *and* reload lobby's nginx; until then lobby keeps dialing the old IP.
- **Every `/support/*` request first hits an `auth_request`** to oauth2-proxy on
  the lobby host at `127.0.0.1:4180`. Anonymous requests get 401 and fall through
  to `@optional_anon`, so **public** pages (the map listing, `latest-version`)
  still work — *unless oauth2-proxy is down*, in which case the subrequest fails
  and even public `/support/*` returns 502.
- **Support's nginx terminates TLS** (`support/public_nginx` role) with a Let's
  Encrypt cert renewed by certbot's timer, over http-01 on port 80. Lobby verifies
  the cert, so an expired cert is an outage, not a warning.
- **Support's 443 is firewalled (ufw) to lobby's public IPv4 and IPv6 only.**
  This is the security boundary: the support app trusts the `X-Auth-*` headers
  lobby's nginx sets, so anyone else reaching 443 could forge MapAdmin. A lobby
  rebuild (new IPs) leaves the rule stale until `support` is redeployed.
- **The support container publishes 8010 on loopback only**
  (`127.0.0.1:8010:8010` in `/opt/support/docker-compose.yml`); only support's
  own nginx reaches it.
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
- **502 fast (<1s)** — upstream actively refused (nothing listening), TLS
  verification failed, or nginx has marked the upstream down.
- **502 after ~60s** — packets are being **dropped/blackholed** (support's
  firewall doesn't admit lobby, or DNS points at a dead IP), not refused.
- **000 / timeout** — a connect that hangs.

Isolate nginx-vs-backend hop by hop. From the **lobby** box, hit support's
nginx over each address family (a firewall gap is often v6-only, which shows up
as intermittent ~60s hangs rather than a clean failure):

```bash
for v in -4 -6; do curl $v -m 5 -sS -o /dev/null -w "$v %{http_code} %{time_total}s\n" \
  https://support.triplea-game.org/support/maps/listing; done
```

From the **support** box, hit the app directly:

```bash
curl -m 5 -sS -o /dev/null -w '%{http_code} %{time_total}s\n' \
  http://127.0.0.1:8010/support/maps/listing
```

If support's loopback is a fast 200 but lobby's curl fails, the fault is support's
nginx, cert, or firewall. If lobby's curl is 200 but the public URL 502s, the
fault is lobby's nginx.

nginx errors are in `/var/log/nginx/error.log` on each host (**not** journald —
the log wrapper won't show them). On lobby, the `upstream: "..."` field names
exactly what nginx dialed — trust it.

## Failure modes (symptom → check → fix)

| # | Symptom | Check | Fix |
|---|---------|-------|-----|
| 1 | lobby nginx dials the **wrong target** (a raw IP, `http://`, or `:8010`) | `sudo nginx -T` on lobby; `grep -r support_backend /etc/nginx/`. The `upstream:` in the error log is the tell. | **Redeploy `main` via CI.** The templates are `https://support.triplea-game.org:443`; anything else means the box drifted from `main` — see "Config drift". |
| 2 | lobby dials a **stale IP** after support was rebuilt | `dig +short support.triplea-game.org` (A and AAAA) vs the Linode's IPs; lobby's error log `upstream:` IP | Fix the DNS records, then `sudo systemctl reload nginx` on lobby. |
| 3 | 502 on **all** `/support/*`, 60s-ish | oauth2-proxy on lobby: `curl -m5 http://127.0.0.1:4180/ping` (expect 200); `systemctl status oauth2-proxy` | `sudo systemctl restart oauth2-proxy` |
| 4 | lobby's traffic **dropped** at support's firewall (all, or v6 only) | On support: `sudo ufw status numbered` — is 443 allowed from lobby's current IPv4 **and** IPv6? From lobby: the `-4`/`-6` curl above. | Redeploy `support` (renders the rule from inventory). |
| 5 | **TLS verify fails** (lobby error log: `SSL_do_handshake`, `certificate verify failed`, `expired`) | On support: `sudo certbot certificates`; `systemctl list-timers \| grep certbot`; is port 80 reachable for renewal? | `sudo certbot renew` on support, then fix whatever blocked the timer. |
| 6 | support container **up but 8010 not on loopback** | On support: `docker ps` PORTS column; `curl http://127.0.0.1:8010/q/health/ready` (instant refuse = not published) | Correct `/opt/support/docker-compose.yml` port to `127.0.0.1:8010:8010`; `docker compose up -d`. Then redeploy `main` to make it stick. |

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

That private-network design has since been replaced: `feat/support-public-dns`
was finished and merged through `main`, giving the public-DNS architecture
described above.

## Safety

- Diagnose read-only: logs via `debugging-triplea-production`/`pull-logs.sh` as
  the `read-only` account; the forensic scripts here only read.
- Fixes are code/infra changes that go through **review + CI on `main`**. Do not
  hand-apply a branch to prod; if you must, revert it before you end the session.
