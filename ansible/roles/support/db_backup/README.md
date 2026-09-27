Nightly backup of the support database, as root's cron at 07:00.
`backup-support-db.sh` writes `backups/support_db_YYYY-MM-DD.sql.gz` under
`/opt/support`, keeps the newest `support_db_backup_retention_count` there,
then rsyncs the day's dump to the lobby host's `/opt/backups/support`, which
keeps the newest 30. Log: `/var/log/triplea-support-db-backup.log`.

The shipping key is generated on this host at apply time and authorized on
the lobby host in the same run, by the `backup_sender` role; see
`roles/marti/db_backup/README.md` for the full flow, which is identical.
