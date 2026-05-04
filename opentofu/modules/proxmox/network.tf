# Internal bridge for LXC/VM traffic (10.50.0.0/24). Not connected to a physical NIC.
# Proxmox host acts as gateway at 10.50.0.254.
resource "proxmox_network_linux_bridge" "internal" {
  node_name = var.node_name
  name      = var.internal_bridge
  address   = "${var.gateway}/24" # /24 matches the internal subnet 10.50.0.0/24
  autostart = true
  comment   = "Internal LXC/VM network"
}
