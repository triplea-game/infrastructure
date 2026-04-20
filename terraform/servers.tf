resource "linode_instance" "servers" {
  for_each = { for k, v in var.servers : k => v if !v.destroy }

  label  = each.key
  region = each.value.region
  type   = each.value.type
  image  = each.value.image
  tags = each.value.tags

  metadata {
    user_data = base64encode(
      templatefile("cloudinit.tpl", { admins = local.admins })
    )
  }

  lifecycle {
    # cloud-init runs once on first boot; changing user_data after the fact
    # would force a replace. Keys and config drift are managed by Ansible.
    # Linode also writes back disk/config details we didn't set, which would
    # otherwise produce persistent phantom diffs.
    ignore_changes = [
      authorized_keys,
      metadata,
      boot_config_label,
      config,
      disk
    ]
  }
}

