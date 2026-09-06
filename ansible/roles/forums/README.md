Sets up the forums that runs as a nodebb server via docker compose, backed by
Postgres 18. The compose stack is two services: `postgres` and `nodebb`.
`backup.sh.j2` backs up the database with `pg_dump` and rsyncs the dump plus the
uploads mirror to the lobby host as `forums-backup`. That key is confined there
to `rrsync -wo`, so the remote paths in the script are relative to the backup
directory rather than absolute (see the `lobby/forums_backup_target` role).
TODO: Overall, we are missing 'nginx' configuration.

The forums Linode is **not** managed by Terraform (`servers.auto.tfvars` marks it
`destroy = true`, pre-existing), so its kernel is set only in the Linode Manager.

## Why Postgres

Forums ran on MongoDB until 2026-09-06, when it moved to Postgres: mongo
refuses to start on Linux kernels ≥6.19 (TCMalloc/rseq ABI incompatibility,
MongoDB SERVER-121912), and a Linode kernel roll onto that range crash-looped
the mongo container and took forums down.
