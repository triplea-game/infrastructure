# Infrastructure Project

Ansible playbooks and Terraform configuration for provisioning and configuring TripleA game servers on Linode.

Ansible manages:
- Admin user accounts & SSH keys
- Firewall rules
- Common utilities (Docker, apt packages)
- Databases (PostgreSQL)
- Reverse proxy (nginx)
- SMTP (postfix)
- Bot processes (managed via systemd)

---

## Quick Start

1. **Get SSH access** — add your SSH public key to `ansible/roles/system/admin_user` in `playbook.yml`, 
   then open a PR. CI/CD will deploy your account on merge.
2. **Set required environment variables** (see section below).
3. **Run a dry-run** to verify everything is working:
   ```bash
   ./run.sh
   ```
   No changes are made by default — it runs in preview/check mode.

---

## Required Environment Variables & Tokens

| Variable | Used By | Purpose | How to obtain |
|---|---|---|---|
| `LINODE_TOKEN` | Terraform | Linode Personal Access Token to provision/manage servers | [Linode Cloud Manager](https://cloud.linode.com/profile/tokens) → Create token |
| `TF_VAR_linode_token` | Terraform | Alternative to `LINODE_TOKEN` — the Terraform Makefile exports one from the other automatically | Same as above |
| `TRIPLEA_ANSIBLE_VAULT_PASSWORD` | Ansible (`ansible/Makefile`) | Password to decrypt Ansible Vault secrets in playbooks | Shared secret — ask a maintainer |
| `SSH_PRIVATE_KEY` | GitHub Actions | Private SSH key for the `deploy-infrastructure` ansible user | See [GitHub Actions secrets](https://github.com/triplea-game/infrastructure/settings/secrets/actions) |

> **Local runs via `run.sh`:** only your personal SSH key (already on servers) is needed — no vault password required unless your playbook targets encrypted variables.
>
> **Local runs via `ansible/Makefile`:** `TRIPLEA_ANSIBLE_VAULT_PASSWORD` must be set.
>
> **Terraform:** `LINODE_TOKEN` or `TF_VAR_linode_token` must be set.

---

## Server Onboarding

### New server on Linode

1. Start server creation in Linode Cloud Manager.
2. Add your SSH public key and mark it to be added to the server.
3. Finish creating the server, then add its IP to `ansible/inventory/prod.inventory`.
4. Temporarily set `remote_user = root` in `ansible/ansible.cfg`.
5. Run the system bootstrap to create all admin accounts:
   ```bash
   ./run.sh --limit [IP-ADDRESS] --tags system
   ```
6. Revert `ansible.cfg` back to the normal ansible user.
7. Delete the temporary root-level SSH keys from your machine.

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

### Using the Ansible Makefile (inside `ansible/`)

```bash
# Preview (check + diff)
make diff

# Apply
make apply

# Apply as the ansible service account
make apply-as-ansible

# Update all bot maps
make update-bots
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

Terraform manages Linode server provisioning. All commands run from the `terraform/` directory via `make`.

**Prerequisite:** `LINODE_TOKEN` must be set.

```bash
export LINODE_TOKEN=<your-linode-pat>
cd terraform/

make init      # Initialize providers
make validate  # Validate configuration
make plan      # Preview changes
make apply     # Apply changes (interactive confirmation)
```

Server definitions live in `terraform/servers.auto.tfvars`. SSH public keys used during provisioning are in `terraform/keys/`.

---

## Secrets & Ansible Vault

Sensitive values in playbooks are encrypted with [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html).

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

On every merge to `master`, GitHub Actions runs Ansible against all production servers:
- Workflow: [`configure-servers.yml`](https://github.com/triplea-game/infrastructure/blob/master/.github/workflows/configure-servers.yml)
- Uses the `deploy-infrastructure` SSH key (stored as `SSH_PRIVATE_KEY` in GitHub Actions secrets)

**Server inventory:** [`ansible/inventory/prod.inventory`](https://github.com/triplea-game/infrastructure/blob/master/ansible/inventory/prod.inventory)

**To add SSH access for a new user:** add their public key to `playbook.yml` under `system/admin_user`, then open a PR — CI/CD will deploy the account on merge.

### Rotating the Ansible SSH key

```bash
ssh-keygen -f ~/.ssh/ansible  # no passphrase
```

1. Update the **private key** in [GitHub Actions secrets](https://github.com/triplea-game/infrastructure/settings/secrets/actions) → `SSH_PRIVATE_KEY`
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
