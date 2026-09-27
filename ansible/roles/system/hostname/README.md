Sets the system hostname (from the Linode label) and templates `/etc/hosts`.

The `hostname` module applies a new name live. Whether the host then reboots is
controlled by `hostname_reboot_on_change`:

- `false` (default): no reboot; the apply prints a notice that a reboot is
  pending for full effect. Stateful hosts (lobby, marti, forums, support) stay
  up, so a relabel in Cloud Manager doesn't drop live games on the next apply.
- `true`: reboot at the end of the play. Set for the `bots` group in
  `group_vars/bots.yml`, since bots are stateless and restart on their own.
