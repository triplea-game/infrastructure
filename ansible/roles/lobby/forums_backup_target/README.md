Receiving side for the forums host's offsite backups, on the lobby host.
Provisions the `forums-backup` account and its `authorized_keys`, plus the
`/opt/backups/forums` destination directories that the `forums` role's
`backup.sh` rsyncs the database dumps and uploads into.
