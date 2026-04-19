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
    # IPs – for_each produces a map, so extract values before iterating
    bot_ips = [for inst in values(linode_instance.servers) : try(inst.ipv4[0], inst.ip_address)]

    # Hostnames (Linode label = hostname if set)
    bot_labels = [for inst in values(linode_instance.servers) : inst.label]
  })
  filename        = "../ansible/inventory/hosts.ini"
  file_permission = "0644"
}
