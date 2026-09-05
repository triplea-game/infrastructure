Key part is the server config file:
 - remove lines to delete bots, add lines to increase them
 - once a bot is added, you'll need to run 'ansible' part



Server configuration and workflow

This directory holds the Terraform root that creates infrastructure. The server list is intended to be the single source of truth for adding/removing Linode instances.

Files
- `variables.tf` - schema for variables (typed `var.servers`).
- `servers.auto.tfvars` - the server definitions (HCL `servers` map), loaded automatically by Terraform. This is the single source of truth for adding/removing servers; it is committed to the repo.

Quick workflow

1) Edit the active server file:

```bash
cd terraform
# edit servers.auto.tfvars to add/remove servers (the `servers` HCL map)
```

2) Validate and apply changes:

```bash
terraform init   # if you haven't already or if providers changed
terraform plan   # shows what will change when you edit the servers map
terraform apply  # apply changes
```

Notes and best practices
- Use the map key (e.g. `Bot04-gb-lon-1`) as the stable logical ID. Do not rename the map key if you want Terraform to keep the same resource. If you must rename, expect a destroy/create cycle.
- Use the `label` attribute to change the provider-visible hostname without renaming the logical key (provider behavior may vary; test in non-prod).
- Admin SSH public keys live in `terraform/keys/admins.json`, referenced by the `admin_pub_file` variable (default `keys/admins.json`). Never commit private keys.
- Copy an existing entry in `servers.auto.tfvars` as the template for new entries.
- Prefer small, reviewable PRs when adding/removing servers. This gives auditability and prevents accidental deletions.

Per-environment handling
- If you manage multiple environments (dev/stage/prod), you can keep per-environment var files (e.g. `servers.prod.tfvars`) and pass `-var-file=servers.prod.tfvars` to Terraform, or use a wrapper like Terragrunt for more advanced overlays.


State is at:
https://app.terraform.io/app/triplea-tf/workspaces/infra/states
