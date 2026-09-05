---
name: adding-admin-user
description: Add or remove a TripleA infrastructure admin maintainer (a passwordless-sudo Linux account with SSH keys) by editing the single source of truth, terraform/keys/admins.json, and committing locally. You make the source edit and STOP — running terraform apply / ansible apply (or merging so CI applies) is the human/CI step, never the agent's.
---

# Adding an admin user

Admins are full passwordless-sudo maintainers of the TripleA servers. Every
entry gets a named Linux account (`admin` + `docker` groups) with
`NOPASSWD:ALL` sudo and its SSH keys installed. There is no admin-vs-regular
tier — an entry is either a full admin or absent.

This repo's `AGENTS.md`/`CLAUDE.md` **forbid you from running
`terraform apply` or mutating `ansible`.** Your job is the source edit + a
local commit. Applying it is out of scope — see below.

## The one edit

Edit only `terraform/keys/admins.json` — the single source of truth (public
keys, plaintext; **no vault/secret edit is needed**). It is a JSON array of
`{ name, ssh_keys[] }`. `name` becomes the Linux username; each key becomes an
`authorized_keys` line. Append one object to add an admin:

```json
{
  "name": "alice",
  "ssh_keys": [
    "ssh-ed25519 AAAA... alice@laptop"
  ]
}
```

Current entries: `ansible` (service account) and `dan`. This one file is read
by two independent consumers, so no other file changes:

- **Ansible** `system/admin_user` role — wired in `ansible/playbook.yml`
  (`hosts: all`, tag `system`) via
  `lookup('file', .../terraform/keys/admins.json) | from_json`. This is what
  propagates a new admin to **already-running** servers.
- **Terraform** — `terraform/locals.tf` decodes the same file into
  `local.admins`, fed to `cloudinit.tpl` by `terraform/servers.tf`. This only
  affects **future** provisioning: cloud-init runs once on first boot, and
  `servers.tf` has `lifecycle { ignore_changes }`. Existing servers are not
  touched by Terraform.

## Then commit and stop

Commit `terraform/keys/admins.json` locally, then STOP. Do not push, do not
merge, do not apply. Hand off to the operator.

## Applying it (human/CI step — NOT the agent)

For reference only; you never run these.

- **Normal path:** open a PR to `main`; on merge, CI
  (`.github/workflows/infrastructure.yml`) runs `terraform apply` then
  `SSH_USER=ansible make apply`. (Per repo rules the agent does not push or
  merge either.)
- **Manual:** from repo root, `APPLY=1 ./run.sh --tags system` — the
  `admin_user` role is under tag `system`, `hosts: all`, so this applies the
  admin everywhere. Needs env: `TRIPLEA_ANSIBLE_VAULT_PASSWORD`,
  `LINODE_TOKEN`/`LINODE_ACCESS_TOKEN`, and the operator's SSH key already on
  the servers (or `SSH_USER=ansible`).
- **Brand-new server:** after Terraform provisions it,
  `APPLY=1 ./run.sh --limit <ip> --tags system` creates the account (the key
  is already injected by cloud-init).

## Removing an admin

Delete that object from `admins.json` and commit. **Critical caveat:** this
does **not** remove the account or keys from existing live servers. The
Ansible role is create-only (`state: present`, no `state: absent`) and
cloud-init won't re-run. Removing the entry only prevents future provisioning;
live boxes keep the account until it is removed **manually**. State this to the
operator.

## Never

- Never run `terraform apply` / `terraform apply-now`, `ansible-playbook`,
  `make apply`, or `APPLY=1 ./run.sh` — applying is the human/CI step.
- Never push or merge to trigger a CI apply.
- Never edit any file other than `terraform/keys/admins.json`.
- No vault or secret edit is needed — admin keys are public plaintext.
