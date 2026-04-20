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
    ignore_changes = [
      authorized_keys,
      metadata,
      boot_config_label,
      config,
      disk
    ]
  }
}

