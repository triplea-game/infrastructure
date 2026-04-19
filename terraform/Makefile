.PHONY: init validate plan apply apply-now destroy fmt fmt-check output

TF_VAR_linode_token ?= $(LINODE_TOKEN)
export TF_VAR_linode_token

ifeq ($(TF_VAR_linode_token),)
  $(error Error: set TF_VAR_linode_token or LINODE_TOKEN before running)
endif

TF=terraform -chdir=$(PWD)

init:
	$(TF) init -upgrade

validate:
	$(TF) validate

plan:
	@echo $$TF_VAR_linode_token
	$(TF) plan -input=false

apply:
	$(TF) apply -input=false

apply-now:
	$(TF) apply -auto-approve

destroy:
	$(TF) destroy -auto-approve

fmt:
	$(TF) fmt -recursive

fmt-check:
	@if [ -n "$(shell $(TF) fmt -recursive -check)" ]; then \
		echo "Run 'make fmt' to fix formatting"; exit 1; \
	fi

output:
	$(TF) apply -target=local_file.ansible_inventory -auto-approve -input=false
	@echo "=== Ansible Inventory ==="
	@cat ../ansible/inventory/hosts.ini

