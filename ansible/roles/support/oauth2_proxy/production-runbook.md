# Production Deployment Run-Book: support-server auth (oauth2-proxy)

This document covers the manual steps required to bring up GitHub authentication
for the support server. Most infrastructure is managed by Ansible — see the
`support/oauth2_proxy` (this role) and `support/nginx_conf` roles. This document
covers only what Ansible does not do automatically, plus the safe deploy order.

---

## Table of Contents

1. [How It Fits Together](#1-how-it-fits-together)
2. [First Deploy: GitHub OAuth App + Vault Secrets](#2-first-deploy-github-oauth-app--vault-secrets)
3. [Deploy Order (Important)](#3-deploy-order-important)
4. [Verifying the Deployment](#4-verifying-the-deployment)
5. [Ongoing Operations](#5-ongoing-operations)

---

## 1. How It Fits Together

The support app runs on its own Linode (`support` host). nginx on the **lobby**
host terminates TLS for `prod.triplea-game.org` and reverse-proxies `/support`
to it over the private network. oauth2-proxy also runs on the **lobby** host
(this role), on loopback `127.0.0.1:4180`, so the nginx auth subrequest is local.

```
browser --443--> nginx (lobby host)
                  |  auth_request -> 127.0.0.1:4180 (oauth2-proxy)   [support/oauth2_proxy]
                  |  /oauth2/*    -> 127.0.0.1:4180 (oauth2-proxy)
                  '--/support     -> support_backend (support Linode, private net)
                                     with sanitized X-Auth-Email / X-Auth-Groups
```

Ansible handles everything below automatically on every deploy:

| What | How |
|---|---|
| oauth2-proxy container + systemd unit | `support/oauth2_proxy` role |
| `.env` (client id/secret, cookie secret) | Rendered from `templates/.env.j2`; vault-encrypted at rest |
| `/oauth2/*` endpoints + `/oauth2/auth` subrequest | `support/nginx_conf` (`server-support.conf`) |
| `/support` (optional-auth) + `/support/admin/` (gated) | `support/nginx_conf` (`server-support.conf`) |
| `X-Auth-*` header sanitization | `support/nginx_conf` (`server-support.conf`) |
| `oauth2_proxy` nginx upstream | `support/nginx_conf` (`pre-server-support.conf`) |

oauth2-proxy binds loopback only — **no firewall change is needed**. The existing
lobby→support:8010 private-network rule (from `support/service`) is unchanged.

---

## 2. First Deploy: GitHub OAuth App + Vault Secrets

One-time, before the first real deploy. The three secrets in
`roles/support/oauth2_proxy/defaults/main.yml` ship as the placeholder string
`"VAULT_TODO"` — oauth2-proxy will start but fail every login until they are real.

### Step 1 — Register the GitHub OAuth App

Create a GitHub OAuth App (org settings → Developer settings → OAuth Apps) with:

| Field | Value |
|---|---|
| Homepage URL | `https://prod.triplea-game.org` |
| Authorization callback URL | `https://prod.triplea-game.org/oauth2/callback` |

Note its **Client ID** and generate a **Client Secret**.

### Step 2 — Generate a cookie secret

```bash
python3 -c 'import os,base64;print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
```

### Step 3 — Vault-encrypt the three secrets

For each value, encrypt it and paste the resulting `!vault |` block in place of
the `"VAULT_TODO"` string in `roles/support/oauth2_proxy/defaults/main.yml`:

```bash
cd ansible
TRIPLEA_ANSIBLE_VAULT_PASSWORD=... ansible-vault encrypt_string \
  --vault-id ./vault-password.sh '<client-id>'      --name 'oauth2_proxy_client_id'
TRIPLEA_ANSIBLE_VAULT_PASSWORD=... ansible-vault encrypt_string \
  --vault-id ./vault-password.sh '<client-secret>'  --name 'oauth2_proxy_client_secret'
TRIPLEA_ANSIBLE_VAULT_PASSWORD=... ansible-vault encrypt_string \
  --vault-id ./vault-password.sh '<cookie-secret>'  --name 'oauth2_proxy_cookie_secret'
```

### Step 4 — Confirm the team matches the app

`oauth2_proxy_github_team` (default `triplea-maps:mapadmins`) must equal the
support app's `app.auth.map-admin-group`. The prod support container does not
override it, so it uses that same default — keep them in sync.

---

## 3. Deploy Order (Important)

The header-sanitization fix (`support/nginx_conf`) and any support image that
trusts `X-Auth-*` must not be separated such that the app trusts the headers
before nginx sanitizes them. Two safe orders:

- **Recommended — nginx first, then app.** Deploy the lobby auth wiring before
  rolling the new support image:

  ```bash
  ansible-playbook playbook.yml --limit lobby --tags nginx,oauth2_proxy
  # then deploy the support app image as usual
  ```

  This is safe at every point: anonymous and optional-auth pages keep working,
  and `/support/admin/` simply redirects to login until oauth2-proxy is live.

- **Together.** Run the full lobby + support plays in one pass:

  ```bash
  ansible-playbook playbook.yml --limit lobby,support
  ```

> ⚠️ Never deploy a support image that reads `X-Auth-*` while the old bare
> `server-support.conf` (no sanitization) is still live — a browser could spoof
> `X-Auth-Email` / `X-Auth-Groups` and gain MapAdmin write access.

---

## 4. Verifying the Deployment

```bash
# oauth2-proxy is up on the lobby host (loopback only)
ssh lobby 'curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4180/ping'   # expect 200

# Public pages work anonymously (no login)
curl -s -o /dev/null -w "%{http_code}\n" https://prod.triplea-game.org/support/maps/listing  # expect 200

# Admin is gated — anonymous request is redirected to GitHub login
curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" https://prod.triplea-game.org/support/admin/
# expect 302 -> https://prod.triplea-game.org/oauth2/start?rd=...
```

Then in a browser: visit `/support/admin/`, complete GitHub login as a
`triplea-maps:mapadmins` member, and confirm you land on the admin page with
write access. A non-member should get 401 from the app after login.

---

## 5. Ongoing Operations

### Logs

```bash
docker compose -f /opt/oauth2-proxy/docker-compose.yml logs -f oauth2-proxy
```

### Restart

```bash
systemctl restart oauth2-proxy
```

### Rotating a secret (client secret or cookie secret)

Re-run Step 3 for the changed value, then re-deploy:

```bash
ansible-playbook playbook.yml --limit lobby --tags oauth2_proxy
```

The `.env` is rewritten and the systemd service restarts the container.
Rotating the **cookie secret** invalidates all existing login sessions (users
re-authenticate); that is harmless. Rotating the **client secret** must be done
in lockstep with regenerating it on the GitHub OAuth App.
