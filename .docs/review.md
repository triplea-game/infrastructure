# Infrastructure Project Review

_Review date: April 2026_

---

## Strengths

- **Dry-run by default** — `run.sh` defaults to check mode, making it safe to run without fear of unintended changes.
- **Systemd-managed bots** — using systemd rather than Docker restart policies is operationally sounder (proper dependency ordering, journal logging, restart backoff).
- **Ansible Vault** — secrets are encrypted at rest; vault password is injected at runtime via env var, not committed.
- **Dynamic Linode inventory** — `inventory/linode.yml` uses the Linode API plugin so the inventory stays in sync with actual infrastructure rather than a hand-maintained static file.
- **Makefile-driven workflows** — both `ansible/Makefile` and `terraform/Makefile` provide clear, reproducible entry points.
- **Concurrency guard** in CI — `cancel-in-progress: true` prevents overlapping deployments.

---

## Weaknesses

| Priority | Weakness |
|---|---|
| 🔴 High | **Two separate Linode token env vars** — Terraform uses `LINODE_TOKEN` / `TF_VAR_linode_token`, Ansible dynamic inventory uses `LINODE_ACCESS_TOKEN`. Easy to configure one but not the other, causing silent failures. |
| 🟠 Medium | **Static `prod.inventory` is still referenced** in `update_bots.sh` and was previously used by `run.sh`. Two inventory sources can diverge silently. |
| 🟠 Medium | **`run.sh` runs Terraform and Ansible sequentially with no separation** — a Terraform failure will block Ansible, and there's no way to run only one without editing the script. |
| 🟡 Low | **`ansible.cfg` has `StrictHostKeyChecking` commented out** — the line exists but is disabled. New servers will fail SSH host-key verification until keys are in `known_hosts`. |
| 🟡 Low | **No Terraform state locking backend** — `terraform.tfstate` is committed to the repo. Concurrent runs (e.g. local + CI) will corrupt state. |
| 🟡 Low | **`terraform/Makefile plan` leaks the token** (`@echo $$TF_VAR_linode_token`) — this will print the secret in plain text in CI logs. |

---

## Potential Bugs

| Priority | Bug | Location |
|---|---|---|
| 🔴 Critical | **Existing `configure-servers.yml` calls `make deploy-test` and `make deploy-prod`** — these targets do not exist in `ansible/Makefile`. The workflow has been silently broken/no-oping. | `.github/workflows/configure-servers.yml` |
| 🔴 Critical | **`terraform/Makefile plan` prints the Linode token in plaintext** (`@echo $$TF_VAR_linode_token`) — will expose secret in any CI log. | `terraform/Makefile` |
| ~~🔴 Critical~~ | ~~**`inventory/linode.yml` missing lobby server**~~ — lobby is a fixed pre-existing resource not managed by Ansible; intentional. | _resolved / by design_ |
| ~~🟠 High~~ | ~~**`update_bots.sh` references wrong inventory path**~~ — fixed, now delegates to `make update-bots`. | _resolved_ |
| ~~🟠 High~~ | ~~**`ansible/Makefile update-bots` references undefined `$ansibleConf` and `$scriptDir`**~~ — fixed, now uses correct `ANSIBLE_CONFIG` and `inventory/linode.yml`. | _resolved_ |
| 🟠 High | **Terraform state in git** — `terraform.tfstate` is tracked in version control. Secrets, IPs, and resource IDs in state may be committed. Concurrent applies will cause state conflicts. | `terraform/terraform.tfstate` |
| 🟡 Medium | **`servers.auto.tfvars` has `destroy = true`** on the lobby server and `Bot-us-east-2` — if `terraform apply` is run these servers will be destroyed. May be intentional (decommission) but is dangerous sitting in a committed file. | `terraform/servers.auto.tfvars` |
| 🟡 Medium | **`ansible/Makefile` `ANSIBLE_VAULT_PASSWORD` assignment is malformed** — the line reads `ANSIBLE_VAULT_PASSWORD ?= $${TRIPLEA_ANSIBLE_VAULT_PASSWORD}h -E '^[a-z]+.*:' ...` which appears to be a copy-paste corruption mixing a variable assignment with a shell pipe. The vault password variable is effectively broken. | `ansible/Makefile` |
| 🟡 Medium | **`run.sh` still references `scriptDir` variable** but it is set to `$(dirname "$0")` and then never used — all `cd` calls use `$(dirname "$0")` directly. Minor dead code, no functional impact. | `run.sh` |

---

## What Could Be Better

### Security
- **Migrate Terraform state to a remote backend** (e.g. Terraform Cloud, S3 + DynamoDB, or Linode Object Storage) with state locking. Remove `terraform.tfstate` from git.
- **Remove the `@echo` of the Linode token** from `terraform/Makefile plan`.
- **Consolidate Linode token env var names** — pick one (`LINODE_TOKEN`) and have the Ansible plugin read from it too, or document the distinction clearly.

### Reliability
- **Add `terraform/` to `.gitignore`** for `*.tfstate`, `*.tfstate.backup`, and `.terraform/`.
- **Pin dependency versions** — `requirements.yml` (Ansible Galaxy), `terraform` provider versions, and the `webfactory/ssh-agent` action should all be pinned to avoid surprise breakage.

### Operational
- **Split `run.sh` into `run-ansible.sh` and `run-terraform.sh`** or accept a `--target` flag, so each can be run independently.
- **Add a health-check / smoke-test step** in CI after apply (e.g. confirm SSH reachable, services running).
- **Document the `destroy = true` pattern** in `servers.auto.tfvars` — it's a useful convention but currently unexplained and dangerous.
- **Clean up legacy `configure-servers.yml`** now that `infrastructure.yml` replaces it. Delete or archive it to avoid confusion.

