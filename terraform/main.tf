terraform {
  required_version = "~> 1.5"

  backend "remote" {
    organization = "triplea-tf"
    workspaces {
      name = "infra"
    }
  }

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
  }
}

variable "linode_token" {
  description = "Linode Personal Access Token. Set via environment variable: export TF_VAR_linode_token=<your_pat>"
  type        = string
  sensitive   = true
}

provider "linode" {
  token = var.linode_token
}
