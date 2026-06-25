resource "linode_instance" "servers" {
  for_each = { for k, v in var.servers : k => v if !v.destroy }

  label      = each.key
  region     = each.value.region
  type       = each.value.type
  image      = each.value.image
  private_ip = each.value.private_ip

  # Linode only persists a server's label and tags, so tags are the only way to
  # carry extra attributes through to the Ansible dynamic inventory, which
  # decodes them back into host vars.
  tags = concat(
    each.value.tags,
    each.value.bot_number != null ? ["botnum-${each.value.bot_number}"] : [],
    each.value.bot_location != null ? ["botlocation-${each.value.bot_location}"] : [],
  )

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

