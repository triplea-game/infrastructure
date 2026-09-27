Nightly backup of the lobby database, as root's cron at 07:00.
`backup-lobby-db.sh` writes `backups/lobby_db_YYYY-MM-DD.sql.gz` under
`/opt/lobby` and keeps the newest `lobby_db_backup_retention_count` there.

These dumps stay on the lobby host: it is the receiver for the other hosts'
offsite copies (`lobby/backup_target`), and nothing receives an offsite copy
of lobby's own database yet, so losing the host loses these backups with it.
