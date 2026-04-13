.PHONY: init validate plan apply apply-now destroy fmt fmt-check

TF_VAR_linode_token ?= $(LINODE_TOKEN)
export TF_VAR_linode_token

ifeq ($(TF_VAR_linode_token),)
  $(error Error: set TF_VAR_linode_token or LINODE_TOKEN before running)
endif

init:
	terraform -chdir=$(PWD) init -upgrade

validate:
	terraform -chdir=$(PWD) validate

plan:
	@echo $$TF_VAR_linode_token
	terraform -chdir=$(PWD) plan -input=false

apply:
	terraform -chdir=$(PWD) apply -input=false

apply-now:
	terraform -chdir=$(PWD) apply -auto-approve

destroy:
	terraform -chdir=$(PWD) destroy -auto-approve

fmt:
	terraform -chdir=$(PWD) fmt -recursive

fmt-check:
	@if [ -n "$(shell terraform -chdir=$(PWD) fmt -recursive -check)" ]; then \
		echo "Run 'make fmt' to fix formatting"; exit 1; \
	fi
