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

variable "bots" {
  description = "Map of bot servers to create. Key is the logical name (used as the Linode label). All bots are automatically tagged 'bot'."
  type = map(object({
    destroy = optional(bool, false)
    type    = optional(string, "g6-nanode-1")
    image   = optional(string, "linode/ubuntu24.04")
    region  = string
  }))
}
