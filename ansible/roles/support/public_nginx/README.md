# support/public_nginx

Puts an nginx + Let's Encrypt TLS front on the support host so lobby reaches it
over a public DNS name (`support.triplea-game.org`) instead of the Linode
same-DC private IP. nginx terminates HTTPS and proxies to the support app on
`127.0.0.1:{{ support_app_port }}`; the app is no longer published on any
external interface.

Why: the private IP was runtime-only config (Linode's Network Helper) and
silently vanished from a running lobby, cutting nginx off from support. A public
DNS name + TLS removes that dependency; TLS also protects the `X-Auth-*` identity
headers, which previously crossed the shared-datacenter private network in
plaintext.

## Security model

443 is firewalled to lobby's public IP only. The support app trusts the
`X-Auth-Email` / `X-Auth-Groups` headers lobby's nginx sets, so lobby must remain
the sole caller — an open 443 would let anyone forge MapAdmin. Port 80 is open to
the world purely for the ACME http-01 challenge.

## Certbot phases (mirror of the marti/nginx_conf pattern)

HTTPS needs a cert that does not exist on a fresh host; the committed vhost is
therefore HTTP-only. Bring TLS up in order:

1. **HTTP only (Ansible).** Deploy this role. nginx serves `:80` and proxies to
   the app on loopback — enough for the http-01 challenge.
2. **Obtain the cert (manual, one-time).** On the support host:
   ```
   certbot --nginx -d support.triplea-game.org
   ```
   Certbot verifies ownership, installs the cert, adds the `:443` server + the
   `80 -> 443` redirect, and registers a renewal timer.
3. **Fold certbot's changes back into the template.** Copy the `# managed by
   Certbot` additions certbot wrote on disk into
   `templates/support.triplea-game.org.conf.j2` so future Ansible runs stay
   idempotent (again, exactly as `marti/nginx_conf` documents).

## Cutover from the private-IP path (zero-downtime)

lobby currently reaches support over the private IP, so sequence the switch so
the new path is live and verified before the old one is torn down:

1. Create DNS `support.triplea-game.org` -> support's public IP (A + AAAA).
2. Temporarily publish the app on **both** the private IP and loopback so both
   paths work during the switch — in `support/service` docker-compose, list both
   `"{{ '{{' }} private_ip {{ '}}' }}:8010:8010"` and `"127.0.0.1:8010:8010"`
   (or accept a brief listing outage and skip this step).
3. Apply this role (`--tags support`), run certbot (phase 2), fold back the
   template (phase 3). Verify `curl -I https://support.triplea-game.org/` from
   lobby.
4. Flip lobby's upstream to the public name (`support/nginx_conf`) and reload
   lobby's nginx. Verify the client map listing loads.
5. Drop the private-IP publish so the app binds loopback only (the committed
   docker-compose state), and re-apply `support/service` — this also removes the
   now-obsolete private-IP 8010 ufw rule and DOCKER-USER block.

Roll out with `just diff` first, and apply to the support host with console
access available, since these tasks reconfigure how the box is reached.
