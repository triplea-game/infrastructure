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

provider "linode" {
  token = var.linode_token
}
