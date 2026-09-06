Pins DNS resolvers into systemd-resolved (drop-in under
`/etc/systemd/resolved.conf.d`) and points `/etc/resolv.conf` at the resolved
stub, so name resolution never depends on a DHCP-delivered nameserver. Servers
are set in `defaults` (`dns_servers` / `dns_fallback_servers`); override per
group in `group_vars`. Runs first in the system play so DNS is up before apt,
docker, and other network-dependent roles.
