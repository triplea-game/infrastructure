Runs oauth2-proxy (GitHub provider) for the support-server auth gate.

Although this is a `support/*` role, it is deployed on the **lobby** host
(see the lobby play in `playbook.yml`), because nginx must reach oauth2-proxy
on loopback (`127.0.0.1:4180`) for the `/oauth2/auth` subrequest. The support
app itself runs on a separate Linode and is reached over the private network.

## Request flow

```
browser --443--> nginx (lobby host)
                  |  auth_request -> 127.0.0.1:4180 (oauth2-proxy)  [this role]
                  |  /oauth2/*    -> 127.0.0.1:4180 (oauth2-proxy)
                  '--/support     -> support_backend (support Linode, private net)
                                     with sanitized X-Auth-Email / X-Auth-Groups
```

The nginx side (the `/oauth2/*` endpoints, the gated `/support` + `/support/admin/`
locations, and header sanitization) lives in the `support/nginx_conf` role.

## One-time setup before first deploy

1. Register a GitHub OAuth App with callback URL
   `https://prod.triplea-game.org/oauth2/callback`; note its client id/secret.
2. Generate a cookie secret:
   `python3 -c 'import os,base64;print(base64.urlsafe_b64encode(os.urandom(32)).decode())'`
3. Vault-encrypt all three into `defaults/main.yml` (see the comments there).
4. Ensure `oauth2_proxy_github_team` matches the app's `app.auth.map-admin-group`.

oauth2-proxy binds loopback only, so no firewall change is needed.
