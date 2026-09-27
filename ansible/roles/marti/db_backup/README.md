Nightly backup of the marti (dice server) database, as root's cron at 07:00.
`backup-marti-db.sh` writes `backups/marti_db_YYYY-MM-DD.sql.gz` under
`/opt/triplea-marti`, keeps the newest `marti_db_backup_retention_count` there,
then rsyncs the day's dump to the lobby host. Log:
`/var/log/triplea-marti-db-backup.log`.

The offsite copy needs no vaulted secret:

1. On apply, the `backup_sender` role generates `/root/.ssh/marti-backup_key`
   on the marti host (once; later applies reuse it).
2. In the same run it sets up the `marti` instance of `lobby/backup_target`
   on the lobby host, through tasks delegated there: the `marti-backup`
   account, its `/opt/backups/marti` jail with the key pinned to
   `rrsync -wo`, and a cron that keeps the newest 30 received dumps.

Rebuilding the marti host generates a new key, and the next apply authorizes
it; the old key stays authorized on the lobby host until removed by hand.
