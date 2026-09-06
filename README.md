# Infrastructure Project

Ansible playbooks and Terraform configuration for provisioning and configuring TripleA game servers on Linode.

Terraform:
- Creates and removes Linode servers
- Initial admin accounts


Ansible manages:
- Admin user accounts
- Firewall rules
- Common utilities (Docker, apt packages)
- Databases (PostgreSQL)
- Reverse proxy (nginx)
- SMTP (postfix)
- Lobby & Bots running on docker

---

## Quick Start

1. **Get SSH access** — add your entry to `terraform/keys/admins.json`, then open a PR. CI/CD will deploy your account on merge. See [Admin Onboarding](#admin-onboarding) for full details.
2. **Set required environment variables** (see section below).
3. **Run a dry-run** to verify everything is working:
   ```bash
   ./run.sh
   ```
   No changes are made by default — it runs in preview/check mode.

---

## Required Environment Variables & Tokens

| Variable | Used By | Where set | Purpose | How to obtain |
|---|---|---|---|---|
| `LINODE_TOKEN` | Terraform (`terraform/justfile`) | Local shell / CI secret | Linode Personal Access Token to provision/manage servers | [Linode Cloud Manager](https://cloud.linode.com/profile/tokens) → Create token |
| `LINODE_ACCESS_TOKEN` | Ansible dynamic inventory (`inventory/linode.yml`) | Local shell / CI secret | Separate Linode token used by the Ansible Linode inventory plugin to discover servers | Same as above — can be the same token value as `LINODE_TOKEN` |
| `TRIPLEA_ANSIBLE_VAULT_PASSWORD` | Ansible (`ansible/justfile`) | Local shell / CI secret | Password to decrypt Ansible Vault secrets in playbooks | Shared secret — ask a maintainer |
| `INFRASTRUCTURE_SSH_PRIVATE_KEY` | GitHub Actions | GitHub Actions secret | Private SSH key for the `deploy-infrastructure` service account | Generate with `ssh-keygen`, store private half here, public half in `playbook.yml` |

**GitHub Actions secrets** (configure at Settings → Secrets → Actions):
- `LINODE_TOKEN`
- `LINODE_ACCESS_TOKEN`
- `TRIPLEA_ANSIBLE_VAULT_PASSWORD`
- `INFRASTRUCTURE_SSH_PRIVATE_KEY`

> **Local runs via `run.sh`:** your personal SSH key (already on servers) + `TRIPLEA_ANSIBLE_VAULT_PASSWORD` + `LINODE_TOKEN` + `LINODE_ACCESS_TOKEN`.
> For **freshly provisioned servers**, SSH in as `<your-username>@<ip>` (your named account from `admins.json`) — your key is injected at provisioning time via `terraform/keys/admins.json`. See [SSH access on freshly provisioned servers](#ssh-access-on-freshly-provisioned-servers).
>
> **Terraform only:** `LINODE_TOKEN` (or `TF_VAR_linode_token`).
>
> **Ansible only:** `TRIPLEA_ANSIBLE_VAULT_PASSWORD` + `LINODE_ACCESS_TOKEN`.

---

## Server Onboarding

### End-to-end provisioning flow

The infrastructure is split into two phases that always run in this order:

1. **Terraform** — provisions the Linode server (compute, networking, cloud-init).
2. **Ansible** — configures the server using the **dynamic inventory** (`inventory/linode.yml`), which discovers servers via the Linode API and groups them by their Linode tags. Those tags become the Ansible host groups (e.g. `lobby`, `bots`).

In CI/CD this is handled automatically (`needs: terraform` ensures ordering). Locally you must run Terraform first, then Ansible.

### SSH access on freshly provisioned servers

`terraform/keys/admins.json` is the **single source of truth for all admin accounts and their public keys**. Both Terraform and Ansible read from this file:

- **Terraform** decodes it at provisioning time and cloud-init creates a **named personal account** for each admin with their SSH keys and passwordless sudo. Any admin can SSH in as themselves immediately after a server boots — no waiting for Ansible, no needing the `ansible` service account key.
- **Ansible** reads the same file via `lookup('file', ...) | from_json` in `playbook.yml` and converges idempotently on top (groups, sudoers file, etc.).

The file format is a JSON array:
```json
[
  {
    "name": "username",
    "ssh_keys": [
      "ssh-ed25519 AAAA... user@host"
    ]
  }
]
```

This means the local bootstrap flow for a freshly provisioned server is simply:

```bash
# 1. SSH in as yourself — cloud-init created a per-admin account named after your admins.json "name"; your key is already there
ssh <your-username>@<new-server-ip>   # verify it's up

# 2. Run Ansible to create all personal accounts and fully configure the server
APPLY=1 ./run.sh --limit <new-server-ip> --tags system
```

After step 2 your personal account exists and you connect normally via your username going forward.

### Admin onboarding

To add a new admin maintainer:

1. **Add their entry** to `terraform/keys/admins.json` — a `{"name": "username", "ssh_keys": [...]}` object.
2. Open a PR. On merge, CI/CD will:
   - Terraform picks up the new key in `admins.json` for any *future* server provisioning (existing servers are unaffected — cloud-init only runs once).
   - Ansible runs and creates the personal account on all existing servers.

> **Removing an admin:** remove their entry from `admins.json` in the same PR.

### New server on Linode

1. Add the server definition to `terraform/servers.auto.tfvars` and run `terraform apply` (or open a PR to let CI/CD do it).
2. Once Terraform completes, run Ansible to fully configure the server:
   ```bash
   APPLY=1 ./run.sh --limit <new-server-ip> --tags system
   ```
   You can SSH in as `<your-username>@<ip>` (your named account from `admins.json`) immediately after provisioning since your key was injected by cloud-init.

### Bootstrapping an existing server (root password access only)

If you only have root password access, manually create the ansible service account first:

```bash
useradd ansible
mkdir -p /home/ansible/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINAUjUJsoqE4NEEnv8Hov06Kn6CNhSDheGRxm7HbLaG9 ansible@triplea" \
  > /home/ansible/.ssh/authorized_keys
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible

echo 'ansible    ALL=(ALL)    NOPASSWD:ALL
Defaults:ansible        !requiretty' > /etc/sudoers.d/ansible
```

Once done, the server can be managed with `./run.sh` as normal.

---

## Running Ansible

`run.sh` is a wrapper around `ansible-playbook`. **By default it runs in dry-run (check) mode** and makes no changes.

```bash
# Preview changes (default — no changes made)
./run.sh

# Apply changes
APPLY=1 ./run.sh

# Limit to a specific host or group
APPLY=1 ./run.sh --limit bots
APPLY=1 ./run.sh --limit lobby

# Apply specific tags only
APPLY=1 ./run.sh --tags system
APPLY=1 ./run.sh --limit [IP] --tags system

# Verbose output
./run.sh --verbose
```

### Using the Ansible justfile (inside `ansible/`)

```bash
# Lint gate (must pass before an apply)
just verify

# Preview (check + diff)
just diff

# Apply
just apply

# Apply as the ansible service account
just apply-as-ansible

# Update all bot maps
just update-bots
```

### Installing Ansible

If Ansible is not installed, `run.sh` will prompt to install it. Or install manually:

```bash
sudo apt update && sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install --yes ansible
ansible-galaxy collection install -r ansible/requirements.yml --force
```

---

## Running Terraform

Terraform manages Linode server provisioning. All commands run from the `terraform/` directory via `just`.

**Prerequisite:** `LINODE_TOKEN` must be set.

```bash
export LINODE_TOKEN=<your-linode-pat>
cd terraform/

just init      # Initialize providers
just validate  # Validate configuration
just plan      # Preview changes
just apply     # Apply changes (interactive confirmation)
```

Server definitions live in `terraform/servers.auto.tfvars`. SSH public keys used during provisioning are in `terraform/keys/`.

---

## Secrets & Ansible Vault

Sensitive values in playbooks are encrypted with [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html).

cd work/triplea-project/infrastructure/ansible
cat [file-with-secret] | ansible-vault encrypt_string --name [ansible-var-name] --vault-password-file vault-password.sh 
```

Encrypt a single variable value:
```bash
secret=<your-secret>
echo -n $secret | ansible-vault encrypt_string --vault-password-file vault_password 2>/dev/null
```

Encrypt a whole file:
```bash
ansible-vault encrypt --vault-password-file vault_password <file>
```

The vault password is stored in `TRIPLEA_ANSIBLE_VAULT_PASSWORD` (locally) and as a GitHub Actions secret.

---

## CI/CD

Workflow: `.github/workflows/infrastructure.yml`

| Trigger | Terraform | Ansible |
|---|---|---|
| Pull Request | `just plan` (preview) | `just verify` (lint) then `just diff` (check + diff) |
| Push to `main` | `just apply-now` | `just verify` (lint) then `just apply` |
| Manual `workflow_dispatch` on `main` | `just apply-now` | `just verify` (lint) then `just apply` |

Ansible runs after Terraform (`needs: terraform`) so newly provisioned servers exist before configuration is applied.

**Required GitHub Actions secrets** (Settings → Secrets → Actions):

| Secret | Purpose |
|---|---|
| `LINODE_TOKEN` | Terraform — provision/destroy Linode servers |
| `LINODE_ACCESS_TOKEN` | Ansible dynamic inventory — discover servers via Linode API |
| `TRIPLEA_ANSIBLE_VAULT_PASSWORD` | Decrypt Ansible Vault secrets |
| `INFRASTRUCTURE_SSH_PRIVATE_KEY` | SSH private key for the `deploy-infrastructure` service account |

### Rotating the Ansible SSH key

```bash
ssh-keygen -f ~/.ssh/ansible  # no passphrase
```

1. Update the **private key** in [GitHub Actions secrets](https://github.com/triplea-game/infrastructure/settings/secrets/actions) → `INFRASTRUCTURE_SSH_PRIVATE_KEY`
2. Update the **public key** in `playbook.yml` under the `deploy-infrastructure` user entry
3. Ensure you have your own SSH access before rotating — rotating breaks CI/CD until the new key is deployed

---

## Bots

Bot processes are managed by **systemd** (not Docker restart policies).

```bash
# Restart a bot
sudo systemctl restart bot@01

# Check status & logs
sudo systemctl status bot@01
sudo journalctl -ubot@01 -n 1000

# List running containers
docker container ls

# Restart via docker (less preferred)
docker stop bot01
```

Download all maps to all bots:
```bash
./update_bots.sh
```


## deploy user - restricted sudo

The `deploy` user is a limited service account used for automated deployments. It is granted passwordless `sudo` for one specific script only - no general root access.

**How it works:**

1. The `admin_user` role creates the `deploy` user and installs `/etc/sudoers.d/deploy`.
2. The `marti/app` role installs `/usr/local/bin/deploy-marti.sh` (owned by root) and drops `/etc/sudoers.d/deploy-marti`:
   ```
   Cmnd_Alias DEPLOY_MARTI = /usr/local/bin/deploy-marti.sh
   deploy    ALL=(ALL)    NOPASSWD: DEPLOY_MARTI
   ```
3. The deploy pipeline connects as `deploy` via SSH and runs `sudo /usr/local/bin/deploy-marti.sh` directly.

**Important:** Ansible's `become: true` must NOT be used for this task. `become` escalates to a root shell via a Python bootstrap, which is not covered by the sudoers rule. The `sudo` call must reference the exact script path from the command line so it matches the `NOPASSWD` entry.

