terraform {
  required_version = ">= 1.11.0" # OpenTofu

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.105"
    }
  }
}
