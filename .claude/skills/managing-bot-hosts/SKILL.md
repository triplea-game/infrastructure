---
name: managing-bot-hosts
description: Add or remove a TripleA lobby bot host (Linode server running headless bot instances). The agent's job is ONE source edit to terraform/servers.auto.tfvars plus a local commit, then STOP — running terraform/ansible to apply is the human/CI step, forbidden to the agent. Use when asked to add, remove, or retire a bot server.
---

# Managing Bot Hosts

Your job is one source edit plus a local commit, then STOP. Bot hosts are Linode
VMs running headless bots that dial OUT to the lobby and self-register — there is
no DNS step. Applying the change (terraform/ansible) is the human/CI step,
forbidden to you.

**Human operators:** the end-to-end procedure — the metadata/tag model, how to
apply (Terraform then Ansible), and recovery — lives in the runbook and is the
source of truth beyond the source edit: `docs/runbooks/managing-bot-hosts.md`.

## The one edit

Edit only `terraform/servers.auto.tfvars` — the `servers` HCL map. An entry:

```hcl
Bot04-gb-lon-1 = { region = "gb-lon", tags = ["bots"], destroy = false, bot_number = 4, bot_location = "London" }
```

- **Add:** append one line with the next unused `bot_number`, a region slug, a
  `bot_location`, `tags = ["bots"]`, `destroy = false`, and a unique stable key
  `Bot<NN>-<region>-<n>` (renaming the key later forces destroy/create).
- **Remove:** set `destroy = true` (preferred — stays auditable) or delete the
  line.

Field meanings and the tag/inventory mechanics are in the runbook.

## Then commit and stop

Commit `terraform/servers.auto.tfvars` locally, then STOP. Hand off to the
operator with a pointer to `docs/runbooks/managing-bot-hosts.md` for applying
(Terraform first, then Ansible for an add).

## Never

- Never run `terraform apply` / `make apply`, `ansible-playbook` /
  `APPLY=1 ./run.sh`, or any mutating terraform/ansible command — even to
  "just plan-and-apply." Applying is the human/CI step.
- Never merge the PR to trigger CI's apply — that's the operator's call.
- Never push, and never edit any file other than
  `terraform/servers.auto.tfvars`.
