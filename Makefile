MAKEFLAGS += --always-make --warn-undefined-variables
SHELL=/bin/bash -eu

nc=\033[0m

help: ## Show this help text
	grep -h -E '^[a-z]+.*:' $(MAKEFILE_LIST) | \
		awk -F ":|#+" '{printf "\033[31m%s $(nc) \n   %s $(nc)\n    \033[3;37mDepends On: $(nc) [ %s ]\n", $$1, $$3, $$2}'

show-install-ansible: ## Prints commands to install ansible (linux)
    # https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html
	@echo sudo apt update
	@echo sudo apt install software-properties-common
	@echo sudo add-apt-repository --yes --update ppa:ansible/ansible
	@echo sudo apt install --yes ansible

deps:
	test -n "$${TRIPLEA_ANSIBLE_VAULT_PASSWORD}"

vaultPassword=@echo "$${TRIPLEA_ANSIBLE_VAULT_PASSWORD}" > ansible/vault-password; trap 'rm -f "ansible/vault-password"' EXIT
runAnsible=$(vaultPassword); ANSIBLE_CONFIG="ansible/ansible.cfg" ansible-playbook --vault-password-file ansible/vault-password
testInventory=--inventory ansible/inventory/test.inventory
prodInventory=--inventory ansible/inventory/prod.inventory
playbook=ansible/playbook.yml

ansible-galaxy-install:
	ansible-galaxy collection install -r ansible/requirements.yml --force

diff-test: ansible-galaxy-install
	$(runAnsible) --check --diff $(testInventory) $(playbook)

deploy-test: ansible-galaxy-install
	$(runAnsible) -vvv $(testInventory) $(playbook)

diff-prod: ansible-galaxy-install
	$(runAnsible) --check --diff $(prodInventory) $(playbook)

deploy-prod: ansible-galaxy-install
	$(runAnsible) $(prodInventory) $(playbook)

update-bots:
	$(ansibleConf) ansible $(EXTRA_ARGS) \
			bots -a 'sudo /home/admin/download-all-maps' \
			--inventory "$scriptDir/ansible/prod.inventory" \
			--verbose
