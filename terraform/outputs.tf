output "ipv4_addresses" {
  description = "Map of server key -> primary public IPv4 address"
  value       = { for k, inst in linode_instance.servers : k => try(inst.ipv4[0], "") }
}

output "instance_ids" {
  description = "Map of server key -> Linode instance ID"
  value       = { for k, inst in linode_instance.servers : k => try(inst.id, "") }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tmpl", {
    # IPs
    bot_ips    = linode_instance.servers[*].ip_address

    # Hostnames (Linode label = hostname if set)
    bot_labels = linode_instance.servers[*].label
  })
  # filename        = "../ansible/inventory/hosts.ini"
  # file_permission = "0644"
}
