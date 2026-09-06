Receiving side for the forums host's offsite backups, on the lobby host.
Provisions the `forums-backup` account and its `authorized_keys`, plus the
`/opt/backups/forums` destination directories that the `forums` role's
`backup.sh` rsyncs the database dumps and uploads into.

The authorized key is pinned to `rrsync -wo /opt/backups/forums`, so it buys a
write-only rsync into that directory and nothing else — no shell, no reading
backups back, no path outside the root. Senders therefore address the dump as
`forums-backup@<host>:/` and the uploads mirror as `:/uploads/`, both relative
to that root.
