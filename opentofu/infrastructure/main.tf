module "hetzner" {
  source = "../modules/hetzner"

  network_name      = var.cluster_name
  talos_hetzner_iso = var.talos_hetzner_iso
  controlplane_nodes = { for k, v in var.controlplane_nodes : k => {
    location    = v.location
    server_type = v.server_type
    private_ip  = v.private_ip
  } }
  network_cidr        = var.network_cidr
  cloud_subnet_cidr   = var.cloud_subnet_cidr
  vswitch_subnet_cidr = var.vswitch_subnet_cidr
  vswitch_id          = var.vswitch_id
  bootstrap_complete  = var.bootstrap_complete
  tags                = { cluster = var.cluster_name }
}

module "talos" {
  source = "../modules/talos"

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.api_hostname # DNS hostname; A records resolve to all CP public IPs
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  install_disk       = var.install_disk
  nameservers        = var.nameservers

  # Static CP info — no public IP here, otherwise we'd cycle via hetzner.user_data.
  controlplane_nodes = {
    for name, n in var.controlplane_nodes : name => {
      private_ip     = n.private_ip
      wireguard_addr = n.wireguard_addr
      install_disk   = n.install_disk
    }
  }

  # Public IPs flow in from hetzner — used only for bootstrap target and the
  # laptop wg0.conf, NOT for machine config generation.
  controlplane_public_ips = module.hetzner.controlplane_public_ips

  worker_nodes = var.worker_nodes

  # Pass these as raw vars (not via hetzner outputs) so machine config
  # generation has no dependency on hetzner resources — keeps the dep graph
  # acyclic.
  cloud_subnet_cidr   = var.cloud_subnet_cidr
  vswitch_subnet_cidr = var.vswitch_subnet_cidr
  network_cidr        = var.network_cidr
  lb_cidr             = var.lb_cidr
  wireguard_clients   = var.laptop_wireguard

  wireguard_node_private_keys = var.wireguard_node_private_keys
  wireguard_node_public_keys  = var.wireguard_node_public_keys
}

module "cloudflare" {
  source = "../modules/cloudflare"

  zone                    = var.cloudflare_zone
  api_hostname            = var.api_hostname
  controlplane_public_ips = module.hetzner.controlplane_public_ips
}
