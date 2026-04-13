# Terraform variables for the Linode instance

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

variable "servers" {
  description = "Map of servers to create. Key is a logical name. Each object must include label, type, and image."
  type = map(object({
    label  = string
    type   = optional(string, "g6-nanode-1")
    image  = optional(string, "linode/ubuntu24.04")
    region = string
    tags   = optional(list(string), [])
  }))
}
