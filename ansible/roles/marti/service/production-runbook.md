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

A push to dice-server-js `main` deploys by running
`/opt/triplea-marti/deploy-marti.sh sha-<commit>` as `marti`. The script pulls
that image and waits for the app's healthcheck (`/health`, which queries the
database). If the app turns unhealthy or is still starting after 150s, the
script redeploys the
image that was running before and exits 1, so the CI deploy fails.

The deployed image is pinned in `/opt/triplea-marti/docker-compose.override.yml`,
which compose merges over the Ansible-managed `docker-compose.yml`. Restarts and
playbook runs keep that image. `marti_image` applies only while no override
exists.

To deploy or roll back by hand, run the script with the tag you want. Every
`main` build is tagged `sha-<full commit sha>`:

```bash
sudo -u marti /opt/triplea-marti/deploy-marti.sh sha-<commit>
```

### Signing Key

Every roll is signed with the RSA-4096 key in
`/opt/triplea-marti/keys/privkey.pem`. Players verify rolls against its public
key, so losing the key breaks verification of every past roll just as rotating
it does.

**Backup.** The key is kept vault-encrypted in `marti_signing_private_key`
(`defaults/main.yml`). With it set, the role installs that key instead of
generating one, so a rebuilt host keeps signing with it. While the variable is
empty, the key lives only on the host. To vault it (run from `ansible/`, as an
account that can read the key, i.e. root on the host):

```bash
ssh <admin>@dice.triplea-game.org 'sudo cat /opt/triplea-marti/keys/privkey.pem' \
  | TRIPLEA_ANSIBLE_VAULT_PASSWORD=... ansible-vault encrypt_string \
      --vault-password-file vault-password.sh --stdin-name marti_signing_private_key
```

Paste the output over `marti_signing_private_key: ""`, then confirm with
`just diff` that the key task reports no change. A change means the vaulted
bytes differ from the host's key.

**Rotation.** The app verifies with a single public key, so switching keys
fails every roll signed before the switch. Until dice-server-js can also check
a list of retired public keys, rotate only when the key is compromised:

1. Generate a new key: `openssl genrsa 4096`, and vault it into
   `marti_signing_private_key` as above.
2. Apply. The role installs the key, derives `pubkey.pem`, and restarts marti.
3. Tell players that rolls signed before the rotation no longer verify.

After a compromise that loss is correct, since anyone holding the old key can
forge "past" rolls. A routine rotation should wait for retired-key support,
then keep each old public key verifiable, so past rolls still check out.

### Applying Vault Secret Changes

After updating a vault-encrypted variable (e.g. `marti_db_password`), re-run
the playbook. The `.env` file will be rewritten and the systemd service will
restart the Compose stack to pick up the new value.

> Changing `marti_db_password` after first deploy will break the database
> connection because the PostgreSQL container was initialized with the original
> password. To change it you must also update the password inside the running
> Postgres instance before redeploying.
