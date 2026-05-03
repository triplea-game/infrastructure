# Marti

## Email (DKIM)

The postfix container uses `DKIM_AUTOGENERATE=yes` to generate a DKIM key pair on first start.
The public key must be manually published as a DNS TXT record - this is a one-time step per server.

### Publishing the DKIM public key

On the server, retrieve the generated public key:

```bash
cat /etc/opendkim/keys/dice.triplea-game.org.txt
```

The file contains the DNS record in zone-file format. Concatenate all quoted string segments
into a single value and add the following DNS record:

- **Name:** `mail._domainkey.dice.triplea-game.org`
- **Type:** `TXT`
- **Value:** `v=DKIM1; h=sha256; k=rsa; s=email; p=<full public key from file>`

### Verifying the DNS record

```bash
dig +short TXT mail._domainkey.dice.triplea-game.org
```

### Current DNS records (required for email delivery)

| Name | Type | Value |
|------|------|-------|
| `dice.triplea-game.org` | A | `97.107.128.227` |
| `dice.triplea-game.org` | TXT | `v=spf1 a -all` |
| `mail._domainkey.dice.triplea-game.org` | TXT | *(DKIM public key from server)* |

The SPF record `v=spf1 a -all` authorizes only the server's own A record IP to send mail,
which is correct since postfix runs on the same host.

### Key rotation

If the server is ever reprovisioned, the `dkim_keys` Docker volume will be lost and a new
key pair will be generated on next start. The DNS record must be updated with the new public key
or outbound email will fail DKIM validation.

