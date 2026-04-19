MAKEFLAGS += --always-make --warn-undefined-variables --environment-overrides
SHELL=/bin/bash -eu

nc=\033[0m
SSH_USER ?= $${USER}

# Env Variables
# TRIPLEA_ANSIBLE_VAULT_PASSWORD: Vault password for Ansible
ANSIBLE_VAULT_PASSWORD ?= $${TRIPLEA_ANSIBLE_VAULT_PASSWORD}h -E '^[a-z]+.*:' $(MAKEFILE_LIST) | \
		awk -F ":|#+" '{printf "\033[31m%s $(nc) \n   %s $(nc)\n    \033[3;37mDepends On: $(nc) [ %s ]\n", $$1, $$3, $$2}'

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
vaultPassword=echo "$${TRIPLEA_ANSIBLE_VAULT_PASSWORD}" > ./vault-password; trap 'rm -f "./vault-password"' EXIT
runAnsible=ANSIBLE_CONFIG="./ansible.cfg" ansible-playbook $(verbosity) --vault-password-file ./vault-password -e ansible_user=$(SSH_USER)
prodInventory=--inventory inventory/linode.yml
playbook=playbook.yml


show-hosts:
	ansible-inventory -i inventory/linode.yml --graph

ansible-galaxy-install:
	ansible-galaxy collection install -r requirements.yml --force

print:
	@echo $(runAnsible) -U --check --diff $(prodInventory) $(playbook)

diff: ansible-galaxy-install
	$(vaultPassword); $(runAnsible) --check --diff $(prodInventory) $(playbook)

apply deploy: ansible-galaxy-install
	$(vaultPassword); $(runAnsible) $(prodInventory) $(playbook)

apply-as-ansible:  ansible-galaxy-install
	SSH_USER=ansible make apply

update-bots:
	$(ansibleConf) ansible $(EXTRA_ARGS) \
			bots -a 'sudo /home/admin/download-all-maps' \
			--inventory "$scriptDir/ansible/prod.inventory" \
			--verbose
