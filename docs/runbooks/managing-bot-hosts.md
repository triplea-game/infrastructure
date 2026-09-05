# Runbook: Managing bot hosts

How to add, remove, or retire a TripleA lobby bot host end to end, including the
apply step. This is the human-operator procedure; an AI agent only performs the
source edit and hands off here for the rest.

## What a bot host is

A bot host is a Linode VM running several headless TripleA bot instances. The
bots dial **out** to the lobby (`LOBBY_URI=https://prod.triplea-game.org`) and
self-register — there is no inbound DNS to add or tear down. The only thing you
manage is the server's existence and its metadata.

Each host runs 3 instances (`01/02/03`, ports `4001-4003`), each registering as
`Bot_<bot_number><instance>_<location>` — eg `Bot_401_London`.

## The single source of truth

Everything is driven by one file, `terraform/servers.auto.tfvars` — the
`servers` HCL map. The schema lives in `variable "servers"` in
`terraform/variables.tf` (provider Linode, pinned in `terraform/main.tf`; state
in Terraform Cloud org `triplea-tf`, workspace `infra`). An entry looks like:

```hcl
Bot04-gb-lon-1 = { region = "gb-lon", tags = ["bots"], destroy = false, bot_number = 4, bot_location = "London" }
```

Field reference:

- **Map key** (`Bot<NN>-<region>-<n>`) — the Linode label and stable logical id.
  Renaming it forces destroy/create, so pick it once and leave it.
- `region` — Linode region slug (`us-east`, `gb-lon`, `eu-central`, …).
- `tags = ["bots"]` — role tag; places the host in the Ansible `bots` group.
- `bot_number` — a unique number; use the next unused one.
- `bot_location` — human label (`London`); surfaces in each bot's registered
  name.
- `destroy` — `false` to keep, `true` to tear down.
- Omitted fields default to `type = "g6-nanode-1"` (the $5 nanode) and
  `image = "linode/ubuntu24.04"`.

`bot_number` and `bot_location` cannot be stored on Linode directly, so
`terraform/servers.tf` emits them as extra tags `botnum-<n>` /
`botlocation-<loc>`. The dynamic inventory `ansible/inventory/linode.yml` groups
by tag and decodes them back into host vars; the `bot` role (`ansible/roles/bot/`,
wired at `ansible/playbook.yml` `hosts: bots`) then configures the box and starts
the instances.

## Adding a bot

1. Append one map line with the next unused `bot_number`, a region slug, a
   `bot_location`, `tags = ["bots"]`, `destroy = false`, and a unique stable key
   following `Bot<NN>-<region>-<n>`.
2. Commit the change.
3. Apply it (see below) — for a new bot you need both the Terraform step and the
   Ansible step.

## Removing a bot

Terraform manages only entries whose `destroy` is false
(`servers.tf`: `for_each = { for k, v in var.servers : k => v if !v.destroy }`),
so dropping an entry from `for_each` makes Terraform destroy the instance. Two
ways:

- **Preferred:** set `destroy = true` on the entry — keeps it auditable in the
  file until a later cleanup.
- Or delete the line entirely.

Commit, then apply the Terraform step. There is no Ansible step and no DNS
teardown; the dynamic inventory simply stops listing the gone host.

## Applying the change

Order is always **Terraform first, then Ansible** — CI enforces it (the ansible
job `needs: terraform` in `.github/workflows/infrastructure.yml`).

1. **Terraform** creates or destroys the VM: open a PR and let CI apply on merge,
   or run manually — `cd terraform && make plan` then `make apply` (needs
   `LINODE_TOKEN` / `TF_VAR_linode_token`).
2. **Ansible** (add only) configures the new box once the dynamic inventory
   discovers it by tag: `APPLY=1 ./run.sh --limit <new-ip> --tags system`, then
   the bot role (`--limit <ip>` or `--limit bots --tags bot`). Optionally seed
   the bot map with `./update_bots.sh`. Needs `LINODE_ACCESS_TOKEN` and
   `TRIPLEA_ANSIBLE_VAULT_PASSWORD`.

## If automation is unavailable

The file edit plus the manual Terraform-then-Ansible steps above are the full
recovery route with no CI and no AI. Preserve the ordering: a bot box that
Terraform has created but Ansible has not yet configured is inert until the bot
role runs against it.
