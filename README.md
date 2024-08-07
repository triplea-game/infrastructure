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

Run `run.sh`, by default it will run in 'dry-run' mode and will not make any
changes but instead will report the changes that would be made.


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

- start server creation process in linode
- add your SSH public key to linode & mark it to be added to the server (you can select this while creating the linode)
- finish creating the server
- add entry to `prod.inventory`
- update `ansible.cfg`, update 'remote-user' to be root
- Run the following: `./run.sh --limit [IP-ADDRESS] --tags system`
- The above will deploy all admin accounts to the server, after which the CI/CD system will be able to manage the server
- Cleanup: Delete the ansible user private & public keys from your machine


To bootstrap an existing server, if we only have root access via password, then we need to create a user account with
a trusted SSH key, and sudo access. Once that is done, the server can be managed via ansible. The below is an example
of creating the needed user account:
```bash
#!/bin/bash
useradd ansible
mkdir -p /home/ansible/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINAUjUJsoqE4NEEnv8Hov06Kn6CNhSDheGRxm7HbLaG9 ansible@triplea" > /home/ansible/.ssh/authorized_keys
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible

echo 'ansible    ALL=(ALL)    NOPASSWD:ALL
Defaults:ansible        !requiretty' > /etc/sudoers.d/ansible
```


## Ops

CI/CD workflow, this runs ansible on any merge to master:
https://github.com/triplea-game/infrastructure/blob/master/.github/workflows/configure-servers.yml

Server list:
<https://github.com/triplea-game/infrastructure/blob/master/ansible/prod.inventory>

To get SSH access, add an account here (then commit & merge, CI/CD will deploy the account automatically):
<https://github.com/triplea-game/infrastructure/blob/master/ansible/roles/system/admin_user/defaults/main.yml>

Of note, when you get SSH access, you can run `./run.sh` out of the box after that point. By default the script
runs in a 'dry-mode' which only reports changes. This is ideal for doing things like:
- checking what will be run
- configuring live servers. Configure the server, make the config changes locally and then run `./run.sh`,
  if it reports no diff, then all config has been successfully made.


### Running Deployments

Update bots:
```
./run.sh --limit bots
```

Update lobby:
```
./run.sh --limit lobby
```



### Bots

Bot process is designed to be managed by systemctl. Systemctl will ensure bot is always running.
(Do not use docker restart=always)


Restart bot (restart can take a while ~60 seconds, sometimes having trouble with clean shut down):
```
sudo systemctl restart bot@01
```

Restart bot via docker (less preferred):
```
docker stop bot01
```

Check bot status & logs:
```
docker container ls
sudo systemctl status bot@01
sudo journalctl -ubot@01 -n 1000
```

## Setting up Ansible user SSH key

```
ssh-keygen
# specify key name: /home/$USER/.ssh/ansible
# no passphrase
```

Update private key: https://github.com/triplea-game/infrastructure/settings/secrets/actions
  - Update secret value, with the new private SSH key: SSH_PRIVATE_KEY

Update public key in `admin_users/default/main.yml`

If you already have a SSH key installed on all the servers, then you can run ansible
with `./run.sh`. Updating the private/public keys for the ansible account will break
github actions. This can easily be fixed by first ensuring you have SSH access,
then running ansible from your local machine with your account.
