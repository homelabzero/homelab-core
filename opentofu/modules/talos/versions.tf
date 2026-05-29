terraform {
  required_version = ">= 1.11.0" # OpenTofu

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }
  }
}
