# Email Spam Troubleshooting

## Most Likely Causes (in priority order)

### 1. Missing DMARC record (highest impact)

DMARC tells receiving mail servers what to do when SPF/DKIM checks fail, and its absence
is a strong spam signal for Gmail and others.

Add this DNS TXT record:

| Name | Type | Value |
|------|------|-------|
| `_dmarc.dice.triplea-game.org` | TXT | `v=DMARC1; p=none; rua=mailto:your@email.com` |

Start with `p=none` (monitor only, no enforcement) so you can observe reports before
tightening policy. Once you confirm SPF and DKIM are passing consistently, move to
`p=quarantine` or `p=reject`.

### 2. Missing PTR / reverse DNS record

Gmail checks that the sending IP has a PTR record matching the hostname. Without it,
emails are more likely to be flagged.

Check the current PTR record:
```bash
dig +short -x 97.107.128.227
```

Expected: `dice.triplea-game.org.`

To fix: set the reverse DNS for the IP in the Linode control panel (under the Networking
tab for the server). Set it to `dice.triplea-game.org`.

### 3. IPv6 fallback delay / missing IPv6 PTR

The logs show postfix tries IPv6 first and fails, then falls back to IPv4. If the server
ever does send via IPv6, that address also needs SPF coverage and a PTR record.

To avoid this entirely and remove the delay, set `inet_protocols = ipv4` in the postfix
config. In the docker-compose environment this is typically set via the `POSTFIX_inet_protocols`
environment variable (or equivalent config injection).

### 4. IP reputation

Linode (now Akamai) IP ranges sometimes carry poor reputation from previous tenants.
Check the sending IP:

- https://mxtoolbox.com/blacklists.aspx - paste `97.107.128.227`
- https://postmaster.google.com - register the domain to get Gmail delivery reports

### 5. Verify DKIM is actually signing outbound mail

Confirm DKIM signatures are present in sent mail headers. Check a received email's
raw headers for a `DKIM-Signature:` field. If it is missing, the opendkim container
may not be correctly integrated with postfix.

Also verify the DNS record is published and valid:
```bash
dig +short TXT mail._domainkey.dice.triplea-game.org
```

## Quick Checklist

- [ ] DMARC TXT record added for `_dmarc.dice.triplea-game.org`
- [ ] PTR record set to `dice.triplea-game.org` in Linode panel
- [ ] Confirm `DKIM-Signature` header present in received emails
- [ ] IP not listed on any blacklists (MXToolbox)
- [ ] (Optional) Register with Google Postmaster Tools for ongoing monitoring

