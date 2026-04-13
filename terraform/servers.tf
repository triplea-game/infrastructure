locals {
  # Keep support for multiple root keys (public SSH file may contain many keys).
  # Use trimspace to remove any surrounding whitespace/newlines reliably.
  raw_root_keys = trimspace(file(var.ssh_pub_file))
  root_keys     = [for k in split("\n", local.raw_root_keys) : trimspace(k) if length(trimspace(k)) > 0]

  # There should only ever be a single ansible key. Read it as a single
  # trimmed string to keep the code simpler and avoid unnecessary lists.
  ansible_key = trimspace(file(var.ansible_pub_file))
}

resource "linode_instance" "servers" {
  for_each = var.servers

  label  = each.value.label
  region = each.value.region
  type   = each.value.type
  image  = each.value.image

  # Set the root authorized keys
  authorized_keys = local.root_keys

  tags = each.value.tags

  metadata {
    user_data = base64encode(
      templatefile("cloudinit.tpl", { root_keys = local.root_keys, ansible_keys = [local.ansible_key] })
    )
  }

  lifecycle {
    # cloud-init runs once on first boot; changing user_data after the fact
    # would force a replace. Keys and config drift are managed by Ansible.
    # Linode also writes back disk/config details we didn't set, which would
    # otherwise produce persistent phantom diffs.
    ignore_changes = [
      metadata,
      boot_config_label,
      config,
      disk,
    ]
  }
}
