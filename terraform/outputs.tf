output "ipv4_addresses" {
  description = "Map of server key -> primary public IPv4 address"
  value       = { for k, inst in linode_instance.servers : k => try(inst.ipv4[0], "") }
}

output "instance_ids" {
  description = "Map of server key -> Linode instance ID"
  value       = { for k, inst in linode_instance.servers : k => try(inst.id, "") }
}

