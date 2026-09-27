---
name: adding-admin-user
description: Add or remove a TripleA infrastructure admin maintainer (a passwordless-sudo Linux account with SSH keys) by editing the single source of truth, terraform/keys/admins.json, and committing locally (a removal also lists the name in removed_admins in ansible/group_vars/all.yml). You make the source edit and STOP — running terraform apply / ansible apply (or merging so CI applies) is the human/CI step, never the agent's.
---

# Adding an admin user

Your job is a source edit plus a local commit, then STOP. Admins are full
passwordless-sudo maintainers; there is no admin-vs-regular tier. Applying the
change (terraform/ansible) is the human/CI step, forbidden to you.

**Human operators:** the end-to-end procedure — the two-consumer model, how to
apply, and the removal caveats — lives in the runbook and is the source of truth
for everything beyond the source edit:
`docs/runbooks/adding-admin-user.md`.

## The one edit

Edit only `terraform/keys/admins.json` — a JSON array of `{ name, ssh_keys[] }`
(public keys, plaintext; no vault edit). Append one object to add an admin:

```json
{
  "name": "alice",
  "ssh_keys": [
    "ssh-ed25519 AAAA... alice@laptop"
  ]
}
```

`name` becomes the Linux username; each key becomes an `authorized_keys` line.
No other file changes — that one file feeds both Ansible and Terraform (see the
runbook for why).

## Removing an admin

Two edits in one commit: delete the object from `admins.json`, **and** add the
name to `removed_admins` in `ansible/group_vars/all.yml`. Deleting only the
`admins.json` entry leaves the account, sudo, and keys on every live server; the
`removed_admins` entry is what makes Ansible delete them. Tell the operator the
name can be dropped from `removed_admins` once an apply has reached every host
(details in the runbook).

## Then commit and stop

Commit locally, then STOP. Hand off to the operator
with a pointer to `docs/runbooks/adding-admin-user.md` for applying.

## Never

- Never run `terraform apply`, `ansible-playbook`, `just apply`, or
  `APPLY=1 ./run.sh` — applying is the human/CI step.
- Never push or merge to trigger a CI apply.
- Never edit any file other than `terraform/keys/admins.json` and, for a
  removal, `removed_admins` in `ansible/group_vars/all.yml`.
