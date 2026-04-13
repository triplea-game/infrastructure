# Terraform Project Review — Changes Applied

Generated: 2026-04-12

---

## What Was Changed and Why

### ✅ 1. `.gitignore` — State files and live tfvars now excluded
**File:** `.gitignore`

Added:
```
terraform.tfstate
terraform.tfstate.backup
*.tfstate
*.tfstate.*
servers.auto.tfvars.json
```

**Why:** The state file contains sensitive data (IPs, disk IDs, encoded SSH keys). The live
`servers.auto.tfvars.json` is the "live" config — the README explicitly said not to commit it.

---

### ✅ 2. `main.tf` — Remote backend, required_version, loosened provider pin
**File:** `main.tf`

- Added `required_version = "~> 1.5"` so collaborators can't accidentally run an incompatible Terraform version.
- Added a `backend "remote"` block pointing at the existing Terraform Cloud workspace (`triplea-tf/infra`) that was already referenced in the README but never wired in. Run `terraform init` to migrate local state up.
- Changed provider version from `"3.0.0"` (exact pin) to `"~> 3.0"` (allows patch/minor upgrades while the lock file still pins the exact hash).

---

### ✅ 3. `servers.tf` — lifecycle block added, commented-out noise removed
**File:** `servers.tf`

Added:
```hcl
lifecycle {
  prevent_destroy = true
  ignore_changes  = [metadata, boot_config_label, config, disk]
}
```

- `prevent_destroy = true` — guards against accidentally destroying a running server by renaming a map key.
- `ignore_changes = [metadata]` — cloud-init only runs once on first boot. Without this, any change to `cloudinit.tpl` would force Terraform to **replace** (destroy + recreate) the instance.
- `ignore_changes = [config, disk]` — Linode writes back disk/config details Terraform didn't set, causing persistent phantom diffs on every plan.
- Removed the commented-out `backups_enabled` and `private_ip` lines (dead noise).

---

### ✅ 4. `variables.tf` — Comment style fixed
**File:** `variables.tf`

Changed `// comment` (non-idiomatic) to `# comment` (standard Terraform/HCL style).
Also fixed minor alignment on the `servers` object type block.

---

### ✅ 5. `cloudinit.tpl` — Redundant sudoers write_files block removed
**File:** `cloudinit.tpl`

Removed the `write_files` section that wrote `/etc/sudoers.d/ansible`. The `sudo: ALL=(ALL) NOPASSWD:ALL`
key in the `users:` block already handles this — the extra file was redundant.

---

## ⚠️ One Manual Step Required

After committing these changes, run:

```bash
cd infrastructure/terraform
terraform init
```

Terraform will detect the new `backend "remote"` block and offer to migrate the existing local state
to Terraform Cloud. Agree to the migration, then delete the local `terraform.tfstate` and
`terraform.tfstate.backup` files (they'll be git-ignored going forward, but the current ones need
to be manually removed from git tracking):

```bash
git rm --cached terraform.tfstate terraform.tfstate.backup
git rm --cached servers.auto.tfvars.json
```

---

## Summary Table

| File | Status | Change |
|---|---|---|
| `.gitignore` | ✅ Done | Added state files + live tfvars |
| `main.tf` | ✅ Done | Remote backend + required_version + ~> pin |
| `servers.tf` | ✅ Done | lifecycle block + cleanup |
| `variables.tf` | ✅ Done | Comment style (#) + alignment |
| `cloudinit.tpl` | ✅ Done | Removed redundant sudoers write_files |
| Manual: `terraform init` | ⚠️ Pending | Migrates local state → Terraform Cloud |
| Manual: `git rm --cached` | ⚠️ Pending | Untracks state + tfvars from git history |

