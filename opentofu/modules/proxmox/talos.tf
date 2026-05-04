resource "proxmox_download_file" "talos_iso" {
  node_name    = var.node_name
  content_type = "iso"
  datastore_id = "local"
  file_name    = "talos-v${var.talos_version}-metal-amd64.iso"
  url          = "https://github.com/siderolabs/talos/releases/download/v${var.talos_version}/metal-amd64.iso"
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.talos_nodes

  node_name     = var.node_name
  vm_id         = each.value.vm_id
  name          = each.key
  on_boot       = true
  scsi_hardware = "virtio-scsi-single"

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  network_device {
    bridge = var.internal_bridge
  }

  disk {
    datastore_id = "local"
    interface    = "scsi0"
    size         = 64
    file_format  = "raw"
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  cdrom {
    file_id = proxmox_download_file.talos_iso.id
  }

  boot_order = ["scsi0", "ide3"]

  operating_system {
    type = "l26"
  }

  agent {
    enabled = false
  }
}
