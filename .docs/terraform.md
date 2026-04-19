# Terraform Reorganization Report

## Current Problems

**main.tf**
- Overloaded: contains backend config, provider block, a variable (`linode_token`), locals, and the server resource all in one file

**servers.tf**
- Misleadingly named — contains variables, not the server resource

**variables.tf**
- Incomplete — `linode_token` variable lives in `main.tf` instead of here

**Makefile**
- Previously pointed to non-existent `modules/` dir — already fixed by user

---

## Proposed Layout

All `.tf` files stay at the top level of `terraform/` — Terraform only reads the
single directory it is pointed at; subdirectories are only used for explicit modules.

```
terraform/
├── backend.tf                   # remote backend block only
├── providers.tf                 # terraform{} + required_providers + provider "linode"
├── variables.tf                 # ALL variables consolidated here
├── locals.tf                    # locals block (SSH key processing)
├── servers.tf                   # linode_instance resource (replaces misleading current content)
├── outputs.tf                   # unchanged
├── cloudinit.tpl                # unchanged
├── servers.auto.tfvars.json     # unchanged
├── servers.example.tfvars.json  # unchanged
├── Makefile                     # unchanged
└── keys/                        # unchanged
    ├── ansible.pub
    └── root.pub
```

---

## Markdown File Audit

### README.md (root)

- Has `## Running` heading **twice** — second one should be removed or merged into the first
- Terraform section is just one line ("Need env variable LINODE_TOKEN") — too sparse; should mention the Makefile and link to `terraform/README.md`
- "Linode Setup" section describes a manual bootstrap flow that partially duplicates the Terraform provisioning — should note that Terraform now handles server creation and this section covers legacy/emergency access only
- Several GitHub links are hardcoded to `master` branch — worth checking they still resolve
- Generally good and detailed; just needs the duplicate heading fixed and a light cleanup

### terraform/README.md

- Does not exist — should be created to document: purpose, prerequisites (`LINODE_TOKEN`), how to use the Makefile targets, and the `servers.auto.tfvars.json` schema

### ansible/roles/*/README.md

- `bot/README.md` — one sentence, adequate for a simple role
- `database/postgres/README.md` — good, explains access pattern clearly
- `reverse_proxy/nginx/README.md` — mentions `dhparam.pem` but does not say where it should live on the server or whether Ansible expects it to already exist
- `system/admin_user/README.md` — good
- `system/apt_packages/README.md` — trailing blank line, otherwise fine
- `system/firewall/README.md` — references `group_vars` for port config but does not say which variable name to look for; adding that would save time

### AGENTS.md

- Clear and correct; no changes needed

---

## Status

- [ ] Pending user confirmation before applying any changes

