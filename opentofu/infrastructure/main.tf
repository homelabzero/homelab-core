module "proxmox" {
  source = "../modules/proxmox"

  node_name       = var.node_name
  talos_version   = var.talos_version
  internal_bridge = var.internal_bridge
  gateway         = var.gateway
  dns_ip          = var.dns_ip
}

module "talos" {
  source = "../modules/talos"

  controlplane_ip = var.controlplane_ip
  worker_nodes    = var.worker_nodes
  nameservers     = var.nameservers
}
