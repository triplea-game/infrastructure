# marti/nginx

Installs and configures nginx as a reverse proxy for the dice server.

## Deployment phases

HTTPS requires a Let's Encrypt certificate that does not exist on a fresh server.
Follow these phases in order.

---

### Phase 1 - HTTP only (Ansible)

Run the playbook normally. Ansible deploys an HTTP-only vhost config that proxies
port 80 traffic to the app on `127.0.0.1:7654`.

At this point the app is reachable over plain HTTP - enough to verify the proxy
is working and for the Let's Encrypt HTTP-01 challenge to succeed.

---

### Phase 2 - Obtain the certificate (manual, one-time)

SSH into the server and run:

```bash
certbot --nginx -d dice.triplea-game.org
```

Certbot will:
1. Verify domain ownership via HTTP-01 challenge
2. Obtain the certificate
3. Modify the nginx config to add SSL directives and an HTTP -> HTTPS redirect
4. Set up a renewal cron/systemd timer automatically

Confirm HTTPS is working before moving to Phase 3:

```bash
curl -I https://dice.triplea-game.org/
```

---

### Phase 3 - Update the Ansible template (once cert is in place)

After certbot runs, the live nginx config on the server will contain SSL directives
with `# managed by Certbot` markers. Copy those additions into the template at:

  `templates/dice.triplea-game.org.conf.j2`

so that future Ansible runs do not overwrite the cert config.

The final template should look similar to:

```nginx
server {
    server_name dice.triplea-game.org;

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/dice.triplea-game.org/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/dice.triplea-game.org/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    location / {
        proxy_pass http://127.0.0.1:7654;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    if ($host = dice.triplea-game.org) {
        return 301 https://$host$request_uri;
    } # managed by Certbot
    listen 80;
    listen [::]:80;
    server_name dice.triplea-game.org;
    return 404; # managed by Certbot
}
```

Once the template matches what certbot put on disk, the role is fully idempotent again.

