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
ansible-vault encrypt $file
```

