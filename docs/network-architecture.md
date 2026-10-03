# Network architecture

How each service is reached, from public DNS down to the process, and where the
firewall sits. Everything here is provisioned by `ansible/` and `terraform/`;
cite the role or file, not the running host, when something looks off.

## The shape of it

Every service is a Linode with a public IP, fronted by nginx that terminates
TLS and reverse-proxies to an app on loopback. There is no load balancer and no
central gateway — each host stands alone, DNS points a name straight at its
public IP, and the box's own nginx is the front door. The one wrinkle is
**support**: it has its own public name and TLS (`support.triplea-game.org`,
nginx on the support box), but users never reach it directly — it is only served
through lobby's nginx under `/support`, which enforces the auth gate and then
proxies to the support box over that public name. So support is two hops behind a
single door.

## Per-service map

| Service | Hostname | Front (TLS terminator) | Backend | Inbound firewall |
|---|---|---|---|---|
| Lobby | `prod.triplea-game.org` | host nginx on the lobby box (`roles/nginx`, Certbot) | lobby container, `127.0.0.1:8080` (client ≤2.6) or `127.0.0.1:8010` (2.7) — `roles/lobby/nginx_conf` | ufw 80/443 |
| Support (user entry) | `prod.triplea-game.org/support` | lobby's nginx + oauth2-proxy auth gate (`roles/support/nginx_conf`, `roles/support/oauth2_proxy`) | proxied over TLS (SNI) to `support.triplea-game.org:443` — the support box's own front | n/a (served off lobby's 443) |
| Support (its box) | `support.triplea-game.org` | nginx + Let's Encrypt on the support box (`roles/support/public_nginx`) | support container on `127.0.0.1:8010` | ufw 443 scoped to lobby's **public** IP; ufw 80 open (ACME only) |
| Marti (dice) | `dice.triplea-game.org` | standalone nginx on the marti box (`roles/marti/nginx_conf`, Certbot) | dice-server-js, `127.0.0.1:7654` | ufw 80/443 |
| Forums | `forums.triplea-game.org` | nginx on the forums box (`roles/forums`, Certbot, HSTS, login rate-limit) | NodeBB, `127.0.0.1:4567` | ufw 80/443 |
| oauth2-proxy | `prod.triplea-game.org/oauth2/*` (internal) | lobby's nginx | oauth2-proxy on the lobby box, `127.0.0.1:4180` | none — binds loopback, no rule |
| Bots | none (no HTTP front) | — | bot containers on ports 4001–4003 | ufw allow 4001–4003 (`roles/bot`) |

## DNS

Managed **outside this repo**. There are no Terraform DNS resources — `grep` for
`domain`/`dns`/`record` under `terraform/` finds nothing. The A/AAAA records
(`prod.`, `dice.`, `forums.`, `support.triplea-game.org`), the marti mail records
(SPF, DKIM `mail._domainkey.dice...`), and everything else are created by hand at
the DNS provider. `group_vars/all.yml` notes for `support_hostname` that "the
A/AAAA record is managed outside this repo"; treat that as the rule for all of
them. When a box is rebuilt its public IP changes (see below), so the matching
record has to be updated by hand.

## Addresses: public and private

**Public IP.** Each Linode gets one public IP from Linode. It is stable for the
life of the instance but changes on rebuild. The Ansible dynamic inventory
derives `ansible_host` from it by taking the first IPv4 that is *not* in the
private range — `inventory/linode.yml` explicitly rejects `^192\.168\.` rather
than trusting `ipv4[0]`, so giving a host a private IP can never change the
address Ansible SSHes to.

**Private IP.** Boxes flagged `private_ip = true` in `terraform/servers.auto.tfvars`
(lobby and support) get a Linode same-datacenter private address, which the
inventory exposes as `private_ip`. Nothing routes over it today — the flag is
kept only to avoid churning the instances (`servers.auto.tfvars` says as much).
It used to carry lobby→support traffic; that path is gone (see "How support is
reached" below). Two things to understand about why it was retired:

- It was **one flat `192.168.128.0/17` segment shared across the whole datacenter
  and across accounts** (see `inventory/linode.yml`).
  It was therefore **not a trust boundary** — anything in the DC that could route to
  the address could reach the port. That is the entire reason the old support 8010
  rule existed and had to be enforced in `DOCKER-USER` (see firewall model below).
- It was **fragile**. The private IP came from Linode's "auto-configure
  networking" Network Helper as runtime-only config that was never persisted
  (see `roles/support/README.md`: check `ip -4 addr` for a `192.*` address). A
  networkd reload on a running lobby silently dropped it, which cut nginx off
  from support with nothing in the config having changed. That failure is why
  support was moved off the private IP entirely.

## Firewall model

Default-deny, per-role opens.

- `roles/system/firewall` sets ufw to **deny incoming / allow outgoing** by
  default and rate-limits SSH (`limit 22/tcp`). It opens nothing else.
- Every service role opens its own ports: `roles/nginx` and the marti/forums
  roles open 80/443, `roles/bot` opens 4001–4003. On the support box
  `roles/support/public_nginx` opens 80 (ACME) and 443 (scoped to lobby's public
  IP); `roles/support/service` no longer opens anything — it only removes the old
  private-IP 8010 rules.

**The Docker subtlety** (now historical, but it shaped the design). ufw does
*not* see Docker-published ports. Docker publishes a port by DNAT'ing it into its
own chain in netfilter's `FORWARD` path, which is reached *before* ufw's `INPUT`
chains — so a `ufw allow`/`deny` on a published port is dead config. In the old
private-IP model the support app was published on `private_ip:8010`, reachable by
anything on the flat DC network. Because the support backend trusts the
`X-Auth-Email` / `X-Auth-Groups` headers lobby's nginx sets (see auth gate
below), an open 8010 was **forgeable MapAdmin**. The fix at the time wrote a rule
into the `DOCKER-USER` chain via `/etc/ufw/after.rules` — the seam Docker
consults first for forwarded traffic and never flushes — scoping 8010 to lobby's
private IP. The public-DNS migration moved the app to loopback (`127.0.0.1:8010`,
never on an external interface), so that rule is now removed by
`roles/support/service` as a converging no-op; the lesson stays relevant for any
future Docker-published port.

## The `/support` auth gate

Support has no login of its own; identity is enforced at lobby's nginx and passed
down as headers.

```
browser --443--> nginx (lobby host)
                  |  auth_request -> 127.0.0.1:4180 (oauth2-proxy)
                  |  /oauth2/*    -> 127.0.0.1:4180 (oauth2-proxy)
                  '--/support     --443/TLS(SNI)--> support.triplea-game.org
                                     (nginx on support box) -> 127.0.0.1:8010
                                     carrying sanitized X-Auth-* headers
```

- **oauth2-proxy** runs on the *lobby* host (not support), on loopback
  `127.0.0.1:4180`, so the `/oauth2/auth` subrequest is local
  (`roles/support/oauth2_proxy`). It uses the GitHub provider; membership of
  `triplea-maps:mapadmins` is what grants write access.
- nginx does an `auth_request` per request, then forwards `X-Auth-Email` /
  `X-Auth-Groups` to support — **always set explicitly**, to the authenticated
  value or to empty via `proxy_set_header` (`roles/support/nginx_conf/templates/server-support.conf`).
  This is the load-bearing bit: a browser can never spoof identity by sending its
  own `X-Auth-*`, because nginx overwrites whatever the client sent. `/support/admin/`
  is hard-gated (anonymous → GitHub login); `/support` public pages are
  optional-auth (anonymous → empty identity).
- The trust chain only holds if lobby's nginx is support's *sole* caller. That is
  why the support box's 443 is firewalled to lobby's **public** IP — a direct hit
  on `support.triplea-game.org` from anywhere else is dropped, so no one can reach
  the backend without passing through lobby's auth gate first.

## How support is reached: public DNS + TLS

This is the model live on `main` today (landed in `035cdca`, "Reach the support
server over public DNS and TLS"). It replaced the private-IP path described in the
historical notes above.

How it fits together:

- **`roles/support/public_nginx`** puts nginx + Let's Encrypt on the support host
  for `support.triplea-game.org`, terminating HTTPS and proxying to the app on
  `127.0.0.1:8010`. Follows the same three-phase Certbot bring-up as
  `roles/marti/nginx_conf` (HTTP-only template → manual `certbot --nginx` →
  fold the `# managed by Certbot` additions back into the template).
- The support app runs **on loopback** — `roles/support/service` docker-compose
  publishes `127.0.0.1:8010`, so it is never on an external interface. The
  obsolete private-IP ufw rule and `DOCKER-USER` block are removed by that role
  (converging no-ops on already-migrated hosts).
- **lobby's upstream** (`roles/support/nginx_conf/pre-server-support.conf`) points
  at `support.triplea-game.org:443` over TLS with SNI. `support_hostname` is
  defined in `group_vars/all.yml` and `roles/support/nginx_conf` refuses to render
  without it.
- **443 on the support host is firewalled to lobby's public IP** only; port 80
  stays open to the world purely for the ACME http-01 challenge.

Why it was built this way: it removed the dependency on the fragile, non-persisted
private IP, and TLS protects the `X-Auth-*` identity headers that previously
crossed the shared DC network in plaintext.

## Why it's built this way

- **nginx-per-host, app-on-loopback** keeps every app off the public interface;
  the only things listening publicly are nginx (80/443) and, on the bot boxes,
  the game ports. TLS and header hygiene live in one place per box.
- **DNS by hand, no Terraform DNS** keeps record management out of the apply
  path — but means a rebuild's new public IP is a manual follow-up.
- **The flat Linode private network is treated as hostile**, not trusted: it
  first drove the `DOCKER-USER` enforcement and then the move off it entirely, to
  public DNS + TLS behind a lobby-scoped firewall.
- **Identity is enforced once, at the edge (lobby's nginx)** and carried as
  sanitized headers, so the support app stays simple — at the cost of requiring
  that support only ever be reachable from lobby.
