# Infrastructure Project


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
