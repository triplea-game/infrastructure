---
name: managing-bot-hosts
description: Add or remove a TripleA lobby bot host (Linode server running headless bot instances). The agent's job is ONE source edit to terraform/servers.auto.tfvars plus a local commit, then STOP — running terraform/ansible to apply is the human/CI step, forbidden to the agent. Use when asked to add, remove, or retire a bot server.
---

# Managing Bot Hosts

Bot hosts are Linode VMs, each running several headless TripleA bot instances
that dial OUT to the lobby (`LOBBY_URI=https://prod.triplea-game.org`) and
self-register. **There is no DNS step** — no inbound A record to add or tear
down; the only thing you manage is the server's existence and its metadata.

You do exactly one thing: make the correct edit to the source of truth and
commit it **locally**. You never apply it (see "Never").

## The source of truth

The **only** file you edit is `terraform/servers.auto.tfvars` — the `servers`
HCL map. Schema lives in `variable "servers"` in `terraform/variables.tf`
(provider Linode, pinned in `terraform/main.tf`; state in Terraform Cloud org
`triplea-tf`, workspace `infra`). Existing bot entries (5 bots, `bot_number`
1-5):

```hcl
Bot04-gb-lon-1 = { region = "gb-lon", tags = ["bots"], destroy = false, bot_number = 4, bot_location = "London" }
```

Key fields:
- **Map key** (`Bot<NN>-<region>-<n>`) = Linode label + stable logical id.
  Renaming it forces destroy/create — pick it once and leave it.
- `region` — Linode region slug (`us-east`, `gb-lon`, `eu-central`, …).
- `tags = ["bots"]` — role tag; puts the host in the Ansible `bots` group.
- `bot_number` — unique number, next unused.
- `bot_location` — human label (`London`), surfaces in each bot's registered
  name.
- `destroy` — `false` to keep, `true` to tear down.
- Omitted fields default: `type = "g6-nanode-1"` ($5 nanode),
  `image = "linode/ubuntu24.04"`.

`bot_number`/`bot_location` can't be stored on Linode directly, so
`terraform/servers.tf` emits them as extra tags `botnum-<n>` /
`botlocation-<loc>`. The dynamic inventory `ansible/inventory/linode.yml`
groups by tag and decodes them back to host vars; the `bot` role
(`ansible/roles/bot/`, wired at `ansible/playbook.yml` `hosts: bots`)
configures the box and starts 3 instances per host (`01/02/03`, ports
`4001-4003`), each registering as `Bot_<bot_number><instance>_<location>`
(e.g. `Bot_401_London`).

## Add a bot

Append one map line with the next unused `bot_number`, a region slug, a
`bot_location`, `tags = ["bots"]`, `destroy = false`, and a unique stable key
following `Bot<NN>-<region>-<n>`. Commit locally. **STOP.**

## Remove a bot

Terraform manages only entries whose `destroy` is false
(`servers.tf`: `for_each = { for k, v in var.servers : k => v if !v.destroy }`),
so making an entry's `destroy` true drops it from `for_each` and Terraform
destroys the instance. Two ways:
- **Preferred:** set `destroy = true` on the entry — keeps it auditable in the
  file until a later cleanup.
- Or delete the line entirely.

Commit locally. **STOP.** No Ansible step and no DNS teardown — the inventory
simply stops listing the gone host.

## Applying it (human/CI, not the agent)

For reference only — do NOT run these. Order is always **Terraform first, then
Ansible** (CI enforces it: the ansible job `needs: terraform` in
`.github/workflows/infrastructure.yml`).

1. **Terraform** creates/destroys the VM: PR → CI applies on merge, or manual
   `cd terraform && make plan` then `make apply` (needs `LINODE_TOKEN` /
   `TF_VAR_linode_token`).
2. **Ansible** (add only) configures the new box once the dynamic inventory
   discovers it by tag:
   `APPLY=1 ./run.sh --limit <new-ip> --tags system`, then the bot role
   (`--limit <ip>` or `--limit bots --tags bot`). Optional map seed:
   `./update_bots.sh`. Needs `LINODE_ACCESS_TOKEN` +
   `TRIPLEA_ANSIBLE_VAULT_PASSWORD`.

## Never

- Never run `terraform apply` / `make apply`, `ansible-playbook` /
  `./run.sh APPLY=1` / `make apply`, or any mutating terraform/ansible command
  — even to "just plan-and-apply." Applying is the human/CI step.
- Never merge the PR to trigger CI's apply — that's the operator's call.
- Never push, and never edit any file other than
  `terraform/servers.auto.tfvars`.
