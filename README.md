# Infrastructure Project


## Running

### Before getting started

- need your SSH public key installed on the servers
   - method 1) add your SSH key to the ansible role that deploys
      admin users. When pushed & merged to master, all servers will
      be updated to have an account for you with your SSH key
   - method 2) if you have access to linode, you can open a 'lish' console
      login as root, create a user & add your SSH key
- "ansible" user should be configured on each server during setup.
  The 'user' configured is important as ansible runs everything over
  SSH, so long as you can SSH, you can run ansible. 

## Running

Run `run.sh`, by default it will run in 'dry-run' mode and will
not make any changes. This will run ansible which will do the full
config of each server (install admin users, their SSH keys, etc..)





## Secrets

Ansible vault encryption: https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html

Encrypt a single value (for a variable)
```
 secret=[some-secret]
echo $secret |  ansible-vault encrypt_string --vault-password-file vault_password 2> /dev/null
```

Encrypt a file:
```
ansible-vault encrypt --vault-password-file vault_password $file
```

## Linode Setup

Add the following as a 'user script' in linode setup

```bash
#!/bin/bash
useradd ansible
mkdir -p /home/ansible/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINAUjUJsoqE4NEEnv8Hov06Kn6CNhSDheGRxm7HbLaG9 ansible@triplea" > /home/ansible/.ssh/authorized_keys
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible


```
