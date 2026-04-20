# Terraform variables for the Linode instance
variable "linode_token" {
  description = "Linode Personal Access Token. Set via environment variable: export TF_VAR_linode_token=<your_pat>"
  type        = string
  sensitive   = true
}


variable "ssh_pub_file" {
  description = "Path (relative to this Terraform folder) to a file containing one or more SSH public keys, one per line"
  type        = string
  default     = "keys/root.pub"
}

variable "ansible_pub_file" {
  description = "Path (relative to this Terraform folder) to the Ansible user's public SSH key(s), one per line"
  type        = string
  default     = "keys/ansible.pub"
}

variable "admin_pub_file" {
  description = "Path (relative to this Terraform folder) to admins.json — a JSON array of {name, ssh_keys[]} objects defining all admin maintainers. Single source of truth consumed by both Terraform (cloud-init) and Ansible (playbook.yml). To add/remove an admin, edit this file and open a PR."
  type        = string
  default     = "keys/admins.json"
}

variable "servers" {
  description = "Map of servers to provision. Key becomes the Linode label. Tags define the server's role (e.g. 'bot', 'lobby')."
  type = map(object({
    destroy = optional(bool, false)
    type    = optional(string, "g6-nanode-1")
    image   = optional(string, "linode/ubuntu24.04")
    region  = string
    tags    = optional(list(string), [])
  }))
}
