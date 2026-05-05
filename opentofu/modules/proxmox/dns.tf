resource "proxmox_download_file" "debian_13" {
  node_name    = var.node_name
  content_type = "vztmpl"
  datastore_id = "local"
  # HTTP is intentional — Proxmox serves templates over HTTP only; integrity is ensured via GPG-signed checksums.
  url = "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"
}

resource "proxmox_virtual_environment_container" "dns" {
  depends_on = [proxmox_sdn_applier.this]

  node_name    = var.node_name
  vm_id        = 100
  description  = "PowerDNS"
  unprivileged = true

  features {
    nesting = true
  }

  start_on_boot = true

  operating_system {
    template_file_id = proxmox_download_file.debian_13.id
    type             = "debian"
  }

  initialization {
    hostname = "dns"

    user_account {
      keys = [trimspace(file(pathexpand(var.ssh_public_key_file)))]
    }

    ip_config {
      ipv4 {
        address = "${var.dns_ip}/24"
        gateway = var.gateway
      }
    }
  }

  network_interface {
    name   = "eth0"
    bridge = proxmox_sdn_vnet.internal.id
  }

  disk {
    datastore_id = "local"
    size         = 4
  }
}
