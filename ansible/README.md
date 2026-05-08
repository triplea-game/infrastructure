sudo apt install pipx
pipx install uv
pipx ensurepath
source ~/.bashrc
ansible-galaxy collection install linode.cloud
## env vars needed

LINODE_ACCESS_TOKEN

uv tool install --with-executables-from ansible-core,ansible-lint,linode_api4 ansible

SSH_USER=ansible make diff

