# Production Deployment Run-Book: dice-server-js

This document covers everything needed to deploy the TripleA Dice Server to a production environment using Docker Compose.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [RSA Key Pair](#2-rsa-key-pair)
3. [PostgreSQL Database](#3-postgresql-database)
4. [SMTP Email Service](#4-smtp-email-service)
5. [Configuration](#5-configuration)
6. [Deployment](#6-deployment)
7. [Reverse Proxy (HTTPS)](#7-reverse-proxy-https)
8. [Firewall](#8-firewall)
9. [Verifying the Deployment](#9-verifying-the-deployment)
10. [Ongoing Operations](#10-ongoing-operations)

---

## 1. Prerequisites

| Requirement | Minimum Version |
|---|---|
| Docker + Docker Compose | Docker 24+ |
| openssl | any |

Docker Compose manages both the application container and the PostgreSQL container. No separate Node.js or PostgreSQL installation is needed on the host.

---

## 2. RSA Key Pair

The server signs every dice roll with an RSA private key so results can be independently verified. Generate these once before first launch and keep them secure.

**Generate the key pair:**

```bash
openssl genrsa -out keys/privkey.pem 4096
openssl rsa -in keys/privkey.pem -outform PEM -pubout -out keys/pubkey.pem
```

The `keys/` directory is mounted into the container read-only at `/app/keys`. The paths above place the files where the default `config.json` expects them.

**Restrict access to the private key:**

```bash
chmod 400 keys/privkey.pem
chmod 444 keys/pubkey.pem
```

> The public key (`pubkey.pem`) can be shared freely - it is used to verify dice roll signatures.
> The private key (`privkey.pem`) must never be exposed. If it leaks, rotate it immediately (see [Key Rotation](#key-rotation)) and notify any users who rely on signature verification.

---

## 3. PostgreSQL Database

The bundled PostgreSQL container creates the database automatically on first start using the environment variables defined in the `.env` file. No manual database setup is required.

The application itself creates the `users` table on first start if it does not already exist.

---

## 4. SMTP Email Service

The server sends transactional emails for registration confirmation and dice roll results. You need credentials for an external SMTP relay - the application does not include a mail server.

Suitable providers include AWS SES, SendGrid, Mailgun, and Postmark. For local testing only, [Ethereal](https://ethereal.email/) provides a dummy SMTP server that captures emails without delivering them.

**Values you will need before proceeding:**

| Value | Description |
|---|---|
| SMTP host | e.g. `smtp.sendgrid.net` |
| SMTP port | `587` (STARTTLS) or `465` (TLS) |
| SMTP username | Provided by your email service |
| SMTP password | Provided by your email service |
| Sender address | The `From:` address in outgoing emails, e.g. `"TripleA Dice Server" <dice@yourdomain.com>` |

> The sender address must match a domain you control with valid SPF and DKIM DNS records, otherwise emails will likely be treated as spam.

---

## 5. Configuration

Configuration comes from two sources, applied in this priority order (highest first):

1. Environment variables - used for secrets so they are never written to disk
2. `config.json` - used for all non-secret settings

### 5.1 config.json

Create `config.json` by copying `config.example.json` and filling in your values:

```bash
cp config.example.json config.json
```

```json
{
  "port": 7654,
  "database": {
    "username": "postgres",
    "host": "postgres",
    "port": 5432,
    "database": "dicedb"
  },
  "email": {
    "smtp": {
      "host": "smtp.yourprovider.com",
      "port": 587
    },
    "display": {
      "sender": "\"TripleA Dice Server\" <dice@yourdomain.com>",
      "server": {
        "protocol": "https",
        "host": "dice.yourdomain.com",
        "port": 443,
        "baseurl": ""
      }
    }
  },
  "keys": {
    "private": "/app/keys/privkey.pem",
    "public": "/app/keys/pubkey.pem"
  }
}
```

**Fields to update:**

| Field | Description |
|---|---|
| `email.smtp.host` | Hostname of your SMTP provider |
| `email.smtp.port` | Port of your SMTP provider |
| `email.display.sender` | The `From:` address for outgoing emails |
| `email.display.server.host` | Your public domain name, e.g. `dice.yourdomain.com` |
| `email.display.server.protocol` | `https` once TLS is configured (see Section 7) |
| `email.display.server.port` | `443` when behind a reverse proxy |

The `email.display.server` fields control the links inside outgoing emails. They must reflect your public URL or registration confirmation links will be broken.

Do not put secrets (passwords) in `config.json` - use environment variables instead (see 5.2).

### 5.2 Environment Variables

Create a `.env` file next to `docker-compose.yml` with the three secret values:

```
DB_PASSWORD=replace-with-strong-password
SMTP_USER=your-smtp-username
SMTP_PASS=your-smtp-password
```

Docker Compose reads this file automatically and injects the values into the containers. These variables map to the following config keys at runtime:

| Variable | Config key |
|---|---|
| `DB_PASSWORD` | `database.password` (and the PostgreSQL container password) |
| `SMTP_USER` | `email.smtp.auth.user` |
| `SMTP_PASS` | `email.smtp.auth.pass` |

> Add `.env` to `.gitignore` so it is never committed to source control.

---

## 6. Deployment

**Required files before starting:**

```
dice-server-js/
  docker-compose.yml
  config.json          # created in step 5.1
  .env                 # created in step 5.2
  keys/
    privkey.pem        # created in step 2
    pubkey.pem         # created in step 2
```

**Start the application:**

```bash
# Build the application image
docker compose build

# Start both containers in the background
docker compose up -d

# Confirm both containers are running (status should be "Up")
docker compose ps

# Tail logs to confirm the app started without errors
docker compose logs -f app
```

A successful start shows the Express server listening on port 7654 with no errors.

**Stop the application:**

```bash
docker compose down
```

**Stop and permanently delete the database (destructive):**

```bash
docker compose down -v
```

---

## 7. Reverse Proxy (HTTPS)

The application does not handle TLS itself. Place it behind a reverse proxy that terminates HTTPS before exposing it to the internet.

**Example nginx configuration (with Let's Encrypt certificates):**

```nginx
server {
    listen 443 ssl;
    server_name dice.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/dice.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dice.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:7654;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 80;
    server_name dice.yourdomain.com;
    return 301 https://$host$request_uri;
}
```

Once TLS is working, confirm that `config.json` has `protocol: "https"`, `host: "dice.yourdomain.com"`, and `port: 443` in the `email.display.server` block, then restart the containers:

```bash
docker compose up -d
```

---

## 8. Firewall

| Port | Service | Publicly reachable? |
|---|---|---|
| 443 | HTTPS (reverse proxy) | Yes |
| 80 | HTTP (redirects to 443) | Yes |
| 7654 | Node.js app | No - reverse proxy only |
| 5432 | PostgreSQL | No - app container only |

The `docker-compose.yml` maps port 7654 on the host. If your reverse proxy runs on the same host, restrict that port to loopback only (`127.0.0.1:7654:7654`) so it is not reachable from outside.

---

## 9. Verifying the Deployment

Run these checks after starting the server:

```bash
# Should return HTTP 200 and an HTML page (the email registration form)
curl -I https://dice.yourdomain.com/

# Should return a JSON error indicating emails are not registered
# (confirms the API is reachable and responding correctly)
curl -s -X POST https://dice.yourdomain.com/api/roll \
  -d "max=6&times=2&email1=test1@example.com&email2=test2@example.com"
```

**Confirm the database is ready:**

```bash
docker compose exec postgres psql -U postgres -d dicedb -c '\dt'
# Expected output: lists the "users" table
```

**Confirm email delivery:**

Visit `https://dice.yourdomain.com/`, register a test email address, and verify the confirmation email arrives in your inbox.

---

## 10. Ongoing Operations

### Logs

```bash
docker compose logs -f app
```

### Database Backups

```bash
docker compose exec postgres pg_dump -U postgres dicedb > dicedb-backup-$(date +%F).sql
```

Add this to a cron job for regular automated backups.

### Key Rotation

If the private key is compromised or needs to be replaced:

1. Generate a new key pair (see Section 2).
2. Replace `keys/privkey.pem` and `keys/pubkey.pem`.
3. Restart the containers: `docker compose up -d`
4. Notify any users who verify dice roll signatures - tokens signed with the old key will no longer pass verification after rotation.

### Updating the Application

```bash
git pull
docker compose build
docker compose up -d
```

### Applying Secret Changes

If you update the `.env` file, restart the containers to pick up the new values:

```bash
docker compose up -d
```
