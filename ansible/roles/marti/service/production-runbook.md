# Production Deployment Run-Book: dice-server-js

This document covers the manual steps required to deploy the TripleA Dice Server.
Most infrastructure is managed by Ansible - see the `marti/app` and `marti/nginx`
roles. This document covers only what Ansible does not do automatically.

---

## Table of Contents

1. [How Deployment Works](#1-how-deployment-works)
2. [First Deploy: HTTPS Certificate](#2-first-deploy-https-certificate)
3. [Verifying the Deployment](#3-verifying-the-deployment)
4. [Ongoing Operations](#4-ongoing-operations)

---

## 1. How Deployment Works

Run the Ansible playbook targeting the `marti` host group:

```bash
ansible-playbook playbook.yml --limit marti
```

Ansible handles everything below automatically. No manual steps are needed for
any of these on subsequent deploys:

| What | How |
|---|---|
| RSA key pair (first deploy only) | Generated on-server with `openssl`; persisted across deploys |
| `config.json` | Rendered from `marti/app/templates/config.json.j2` |
| `.env` (DB password) | Rendered from `marti/app/templates/.env.j2`; vault-encrypted at rest |
| `docker-compose.yml` | Rendered from `marti/app/templates/docker-compose.yml.j2` |
| systemd service | Rendered from `marti/app/templates/marti.service.j2`; starts on boot |
| nginx reverse proxy | Deployed by `marti/nginx` role |
| Firewall (ports 80, 443) | Opened by `marti/nginx` role via `ufw` |

**Services in the Compose stack:**

| Service | Image | Purpose |
|---|---|---|
| `app` | `ghcr.io/triplea-game/dice-server-js:<digest>` | Node.js dice server, port 7654 (loopback only) |
| `postgres` | `postgres:16` | Database; password from `.env` |
| `postfix` | `boky/postfix` | Internal SMTP relay with auto-generated DKIM keys |

Email is sent through the internal `postfix` container. No external SMTP
credentials are needed.

---

## 2. First Deploy: HTTPS Certificate

HTTPS requires a Let's Encrypt certificate. This is a one-time manual step
because certbot must make an outbound HTTP-01 challenge before a cert exists.

### Phase 1 - Run Ansible (HTTP only)

The `marti/nginx` role deploys an HTTP-only vhost on port 80 that proxies to
the app. This is enough to verify the proxy works and for certbot to complete
its challenge.

### Phase 2 - Obtain the certificate

SSH into the server and run:

```bash
certbot --nginx -d dice.triplea-game.org
```

Certbot will verify domain ownership, fetch the certificate, update the nginx
config, and register an auto-renewal timer.

Confirm HTTPS is working:

```bash
curl -I https://dice.triplea-game.org/
```

### Phase 3 - Update the Ansible template

After certbot runs, copy the SSL directives certbot added to the live nginx
config into `marti/nginx/templates/dice.triplea-game.org.conf.j2` so future
Ansible runs do not overwrite them. See `marti/nginx/README.md` for the
expected final template shape.

---

## 3. Verifying the Deployment

```bash
# Should return HTTP 200
curl -I https://dice.triplea-game.org/

# Should return a JSON error about unregistered emails (confirms the API is up)
curl -s -X POST https://dice.triplea-game.org/api/roll \
  -d "max=6&times=2&email1=test1@example.com&email2=test2@example.com"
```

Confirm the database is ready:

```bash
docker compose -f /opt/triplea-marti/docker-compose.yml exec postgres \
  psql -U postgres -d dicedb -c '\dt'
# Expected: lists the "users" table
```

Confirm email delivery by visiting `https://dice.triplea-game.org/`, registering
a test address, and checking your inbox.

---

## 4. Ongoing Operations

### Logs

```bash
docker compose -f /opt/triplea-marti/docker-compose.yml logs -f app
```

### Database Backups

```bash
docker compose -f /opt/triplea-marti/docker-compose.yml exec postgres \
  pg_dump -U postgres dicedb > dicedb-backup-$(date +%F).sql
```

Add this to a cron job for automated backups.

### Updating the Application

Update the image digest in `ansible/roles/marti/app/defaults/main.yml`
(`marti_image`), then re-run the playbook:

```bash
ansible-playbook playbook.yml --limit marti
```

The systemd service restarts the Compose stack automatically.

### Key Rotation

If the RSA private key is compromised:

1. Delete `keys/privkey.pem` and `keys/pubkey.pem` on the server under
   `/opt/triplea-marti/keys/`.
2. Re-run the Ansible playbook - it will regenerate the key pair.
3. Restart the stack: `systemctl restart marti`.
4. Notify any users who verify dice roll signatures - tokens signed with the
   old key will no longer pass verification.

### Applying Vault Secret Changes

After updating a vault-encrypted variable (e.g. `marti_db_password`), re-run
the playbook. The `.env` file will be rewritten and the systemd service will
restart the Compose stack to pick up the new value.

> Changing `marti_db_password` after first deploy will break the database
> connection because the PostgreSQL container was initialized with the original
> password. To change it you must also update the password inside the running
> Postgres instance before redeploying.
