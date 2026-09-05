# Runbook: Adding or removing an admin user

How to add or remove a TripleA infrastructure admin maintainer end to end,
including the apply step. This is the human-operator procedure; an AI agent only
performs the source edit and hands off here for the rest.

## What an admin is

An admin is a full, passwordless-sudo maintainer of the TripleA servers. Every
entry becomes a named Linux account in the `admin` and `docker` groups, with
`NOPASSWD:ALL` sudo and its SSH keys installed. There is no admin-vs-regular
tier: an entry is either a full admin or absent.

## The single source of truth

Everything is driven by one file, `terraform/keys/admins.json` — a JSON array of
`{ name, ssh_keys[] }`, where `name` becomes the Linux username and each key
becomes an `authorized_keys` line. The keys are public plaintext; there is no
vault or secret to edit.

That one file is read by two independent consumers, which is why nothing else
needs to change — and why *when* a change takes effect depends on which consumer
you rely on:

- **Ansible** (`system/admin_user` role, wired in `ansible/playbook.yml` under
  `hosts: all`, tag `system`) reads the file with
  `lookup('file', .../terraform/keys/admins.json) | from_json`. This is what
  propagates a new admin to **already-running** servers.
- **Terraform** (`terraform/locals.tf` decodes it into `local.admins`, fed to
  `cloudinit.tpl` by `terraform/servers.tf`) only affects **future**
  provisioning. Cloud-init runs once on first boot, and `servers.tf` sets
  `lifecycle { ignore_changes }`, so existing servers are never touched by
  Terraform.

The practical consequence: Terraform alone will not add an admin to a running
box, and removing an entry will not evict them from one. Ansible is the lever for
live servers.

## Adding an admin

1. Append one object to `terraform/keys/admins.json`:

   ```json
   {
     "name": "alice",
     "ssh_keys": [
       "ssh-ed25519 AAAA... alice@laptop"
     ]
   }
   ```

2. Commit the change.
3. Apply it (see below). To reach live servers you must run the Ansible path.

## Removing an admin

Delete that object from `admins.json` and commit.

**Critical caveat — removal is not automatic on live servers.** The Ansible role
is create-only (`state: present`, no `state: absent`), and cloud-init does not
re-run. Deleting the entry only stops *future* provisioning from recreating the
account; every currently-running server keeps the account and its keys until you
remove them **manually** on each box. If you are removing someone for a security
reason, the file edit is not sufficient — you must also revoke on the live hosts.

## Applying the change

Order is always Terraform first, then Ansible (CI enforces it). Adding an admin
to running servers only needs the Ansible/`system` path.

- **Normal path (CI):** open a PR to `main`. On merge, CI
  (`.github/workflows/infrastructure.yml`) runs `terraform apply` and then
  `SSH_USER=ansible make apply`.
- **Manual, all servers:** from the repo root,
  `APPLY=1 ./run.sh --tags system`. The `admin_user` role is under tag `system`
  with `hosts: all`, so this applies the admin everywhere. Requires the
  environment: `TRIPLEA_ANSIBLE_VAULT_PASSWORD`, `LINODE_TOKEN` (or
  `LINODE_ACCESS_TOKEN`), and either your own SSH key already on the servers or
  `SSH_USER=ansible`.
- **Brand-new server:** after Terraform provisions it,
  `APPLY=1 ./run.sh --limit <ip> --tags system` creates the account (its key is
  already injected by cloud-init).

## If automation is unavailable

The file edit plus the manual `./run.sh --tags system` path above is the full
recovery route with no CI and no AI. If you cannot run Ansible at all, an admin
can be added by hand on a single box by creating the Linux account in the `admin`
and `docker` groups, granting `NOPASSWD:ALL`, and installing the key in
`authorized_keys` — but record it in `admins.json` afterward so the box does not
drift from the source of truth.
