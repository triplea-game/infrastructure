MAKEFLAGS += --always-make --warn-undefined-variables
SHELL=/bin/bash -ue

nc=\033[0m

# Skip DB install on prod. We installed "postgres" in prod, which might not be exactly the
# postgres-12 package that we need to install on test.
prod_extra_args=--skipTags=database

## Use env variable "EXTRA_ARGS" to add to the ansible CLI command, eg:
# make deploy-test EXTRA_ARGS="-t database"

help: ## Show this help text
	grep -h -E '^[a-z]+.*:' $(MAKEFILE_LIST) | \
		awk -F ":|#+" '{printf "\033[31m%s $(nc) \n   %s $(nc)\n    \033[3;37mDepends On: $(nc) [ %s ]\n", $$1, $$3, $$2}'

show-install-ansible: ## Prints commands to install ansible (linux)
    # https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html
	@echo sudo apt update
	@echo sudo apt install software-properties-common
	@echo sudo add-apt-repository --yes --update ppa:ansible/ansible
	@echo sudo apt install --yes ansible

all diff-test:
	ANSIBLE_CONFIG="./ansible.cfg" \
		ansible-playbook $(EXTRA_ARGS) \
			--check \
			--diff \
			--inventory ansible/test.inventory \
			ansible/playbook.yml

deploy-test:
	ANSIBLE_CONFIG="./ansible.cfg" \
		ansible-playbook $(EXTRA_ARGS) \
			--diff \
			--inventory ansible/test.inventory \
			ansible/playbook.yml

diff-prod:
	ANSIBLE_CONFIG="./ansible.cfg" \
		ansible-playbook $(EXTRA_ARGS) $(prod_extra_args) \
			--check \
			--diff \
			--inventory ansible/prod.inventory \
			ansible/playbook.yml

update-bots:
	ANSIBLE_CONFIG="$scriptDir/ansible.cfg"
		ansible $(EXTRA_ARGS) \
			bots -a 'sudo /home/admin/download-all-maps' \
			--inventory "$scriptDir/ansible/prod.inventory" \
			--verbose

nginx:
	./run.sh -t nginx --diff


deploy-prod:
	# prod_extra_args
