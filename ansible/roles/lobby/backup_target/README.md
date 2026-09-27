Receiving side for offsite database backups, on the lobby host. Each instance
(one per sending host, named by `backup_target_name`) provisions a
`<name>-backup` account, its `/opt/backups/<name>` destination directory, and a
nightly prune that keeps the newest `backup_target_retention_count` dumps.

A sender's key is pinned to `rrsync -wo /opt/backups/<name>`, so it buys a
write-only rsync into that one directory and nothing else — no shell, no
reading backups back, no path outside the root. Senders therefore address the
dump as `<name>-backup@<host>:/`, relative to that root.

Keys arrive one of two ways:

- **Fixed key** (forums): the public key is set as `backup_target_public_key`
  on the instance in `playbook.yml`, and this role authorizes it.
- **Generated key** (marti): the `backup_sender` role creates the keypair on
  the sending host at apply time and runs this role's `authorize` tasks,
  delegated here. The lobby play runs first and creates the account, so a
  fresh fleet converges in one full apply; a `--limit` to the sender alone
  against a lobby host that never had the instance fails at the authorize step.
