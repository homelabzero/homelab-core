module "proxmox" {
  source = "../modules/proxmox"

  node_name        = var.node_name
  talos_version    = var.talos_version
  sdn_zone         = var.sdn_zone
  sdn_vnet         = var.sdn_vnet
  subnet_cidr      = var.subnet_cidr
  gateway          = var.gateway
  dns_ip           = var.dns_ip
  dhcp_dns_server  = var.dhcp_dns_server
  dhcp_range_start    = var.dhcp_range_start
  dhcp_range_end      = var.dhcp_range_end
  ssh_public_key_file = var.ssh_public_key_file
}

module "talos" {
  source = "../modules/talos"

  controlplane_name = var.controlplane_name
  worker_nodes      = toset(var.worker_nodes)
  nameservers       = var.nameservers
  node_initial_ips  = module.proxmox.talos_node_ips
  schematic_id      = module.proxmox.talos_schematic_id
  talos_version     = var.talos_version
}
