Receiving side for offsite database backups, on the lobby host. Each instance
(one per sending host, named by `backup_target_name`) provisions a
`<name>-backup` account, its `/opt/backups/<name>` destination directory, the
sender's authorized key, and a nightly prune that keeps the newest
`backup_target_retention_count` dumps.

A sender's key is pinned to `rrsync -wo /opt/backups/<name>`, so it buys a
write-only rsync into that one directory and nothing else — no shell, no
reading backups back, no path outside the root. Senders therefore address the
dump as `<name>-backup@<host>:/`, relative to that root.

Every task delegates to the lobby host, so an instance is set up from one of
two places:

- **Fixed key** (forums): an instance in the lobby play in `playbook.yml`,
  with the public key set as `backup_target_public_key`.
- **Generated key** (marti, support): the `backup_sender` role creates the
  keypair on the sending host at apply time and runs this role from the
  sender's own play, passing the public half in. Play order doesn't matter,
  and a `--limit` to the sender still reaches the lobby host.
