locals {
  # Admin maintainers — decoded from admins.json, which is the single source of
  # truth for all admin accounts and their SSH keys. Terraform uses this to
  # create named personal accounts in cloud-init; Ansible reads the same file
  # via lookup() in playbook.yml.
  admins = tolist([
    for admin in jsondecode(file(var.admin_pub_file)) : {
      name     = tostring(admin.name)
      ssh_keys = tolist([for k in admin.ssh_keys : tostring(k)])
    }
  ])
}
