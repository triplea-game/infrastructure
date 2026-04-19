# Root Terraform configuration: version constraints, remote backend, and provider declarations.
terraform {
  required_version = "~> 1.5"

  # State is stored remotely in Terraform Cloud under the "triplea-tf" organization.
  backend "remote" {
    organization = "triplea-tf"
    workspaces {
      name = "infra"
    }
  }

  required_providers {
    # Linode provider for managing cloud infrastructure (VMs, networking, etc.).
    linode = {
      source  = "linode/linode"
      version = "3.0.0"
    }
    # Local provider for writing files (e.g. generated Ansible inventory).
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# Authenticates with Linode using a token supplied via variable (see variables.tf).
provider "linode" {
  token = var.linode_token
}
