MAKEFLAGS += --always-make --warn-undefined-variables --environment-overrides
SHELL=/bin/bash -eu

nc=\033[0m
SSH_USER ?= $${USER}

# Env Variables
# TRIPLEA_ANSIBLE_VAULT_PASSWORD: Vault password for Ansible (used by vault-password.sh)

show-install-ansible: ## Prints commands to install ansible (linux)
    # https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html
	@echo sudo apt update
	@echo sudo apt install software-properties-common
	@echo sudo add-apt-repository --yes --update ppa:ansible/ansible
	@echo sudo apt install --yes ansible

deps:
	test -n "$${TRIPLEA_ANSIBLE_VAULT_PASSWORD}"

verbosity=
#verbosity=-vvv
runAnsible=ANSIBLE_CONFIG="./ansible.cfg" ansible-playbook $(verbosity) --vault-password-file ./vault-password.sh -e ansible_user=$(SSH_USER)
prodInventory=--inventory inventory/linode.yml
playbook=playbook.yml


show-hosts:
	ansible-inventory -i inventory/linode.yml --graph

ansible-galaxy-install:
	ansible-galaxy collection install -r requirements.yml --force

print:
	@echo $(runAnsible) -U --check --diff $(prodInventory) $(playbook)

diff plan: ansible-galaxy-install
	$(runAnsible) --check --diff $(prodInventory) $(playbook)

apply deploy: ansible-galaxy-install
	$(runAnsible) $(prodInventory) $(playbook)

apply-as-ansible:  ansible-galaxy-install
	SSH_USER=ansible make apply

update-bots:
        ANSIBLE_CONFIG="./ansible.cfg" ansible \
                bots -a 'sudo /home/admin/download-all-maps' \
                --inventory inventory/linode.yml \
                --verbose
