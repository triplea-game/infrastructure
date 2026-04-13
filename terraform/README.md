Key part is the server config file:
 - remove lines to delete bots, add lines to increase them
 - once a bot is added, you'll need to run 'ansible' part



Server configuration and workflow

This directory holds the Terraform root that creates infrastructure. The server list is intended to be the single source of truth for adding/removing Linode instances.

Files
- `variables.tf` - schema for variables (typed `var.servers`).
- `servers.example.tfvars.json` - example/template for the servers map. Copy this to `servers.auto.tfvars.json` and edit to manage your servers.
- `servers.auto.tfvars.json` (optional) - the actual server definitions loaded automatically by Terraform. Do NOT commit secrets to repo.

Quick workflow

1) Create or update the active server file:

```bash
cd /home/dan/work/triplea-project/infrastructure/terraform
cp servers.example.tfvars.json servers.auto.tfvars.json   # create from template (one-time)
# edit servers.auto.tfvars.json to add/remove servers
```

2) Validate and apply changes:

```bash
terraform init   # if you haven't already or if providers changed
terraform plan   # shows what will change when you edit the servers map
terraform apply  # apply changes
```

Notes and best practices
- Use the map key (e.g. `bot01`) as the stable logical ID. Do not rename the map key if you want Terraform to keep the same resource. If you must rename, expect a destroy/create cycle.
- Use the `label` attribute to change the provider-visible hostname without renaming the logical key (provider behavior may vary; test in non-prod).
- Keep ssh public keys in files referenced by `ssh_pub_file` and `ansible_pub_file`. Never commit private keys.
- Use `servers.example.tfvars.json` as the template for new entries. Keep `servers.auto.tfvars.json` as the live file that Terraform loads automatically.
- Prefer small, reviewable PRs when adding/removing servers. This gives auditability and prevents accidental deletions.

Per-environment handling
- If you manage multiple environments (dev/stage/prod), you can keep per-environment var files (e.g. `servers.prod.tfvars`) and pass `-var-file=servers.prod.tfvars` to Terraform, or use a wrapper like Terragrunt for more advanced overlays.


State is at:
https://app.terraform.io/app/triplea-tf/workspaces/infra/states
