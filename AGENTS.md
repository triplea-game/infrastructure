Do not:
- run terraform apply
- run ansible that would make changes (run with check mode only)
- make changes to servers or push configurations
- check in code without confirming with user


## Connecting to servers

Connect **only** as the `read-only` account (`read_only_user`
in `ansible/group_vars/all.yml`) — never any other account.

Reading production logs is the usual reason to connect: use the
`debugging-triplea-production` skill (`.claude/skills/debugging-triplea-production/`),
which carries the sanctioned wrapper and how to resolve server IPs.

