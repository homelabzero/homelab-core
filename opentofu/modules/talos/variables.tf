###########################################################################
# Global
###########################################################################

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the Hetzner network."
}

###########################################################################
# Network
###########################################################################

variable "network_cidr" {
  type        = string
  description = "Full Hetzner private network CIDR — worker route target"
}

variable "cloud_subnet_cidr" {
  type        = string
  description = "Hetzner cloud subnet CIDR — used to pin etcd peer traffic"
}

variable "vswitch_subnet_cidr" {
  type        = string
  description = "Hetzner vswitch subnet CIDR — worker VLAN sub-interface lives here"
}

variable "private_mtu" {
  type        = number
  default     = 1400
  description = "MTU on the private NIC / vSwitch VLAN. Hetzner vSwitch path is 1400."
}

###########################################################################
# Cluster
###########################################################################

variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
}

variable "talos_version" {
  type        = string
  description = "Talos version contract (e.g. 1.13.0). Initial install image is derived from this."
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Kubernetes version. If null, the Talos provider's default is used."
}

variable "cluster_endpoint" {
  type        = string
  description = "kube-apiserver hostname or IP (no scheme, no port). Embedded in machine config and kubeconfig."
}

variable "install_disk" {
  type    = string
  default = "/dev/sda"
}

variable "nameservers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

variable "controlplane_nodes" {
  type = map(object({
    private_ip     = string
    wireguard_addr = string           # CIDR e.g. 10.25.0.3/24
    install_disk   = optional(string) # falls back to var.install_disk
  }))
  description = "Map of CP node name to private IP (cloud subnet) and WireGuard CIDR address. Public IPs are passed separately via controlplane_public_ips."
}

variable "controlplane_public_ips" {
  type        = map(string)
  description = "Map of CP node name to public IPv4 — passed in from the hetzner module after VM creation. Used for laptop WG endpoint and the bootstrap target."
}

variable "worker_nodes" {
  type = map(object({
    public_ip        = string
    private_ip       = string           # static IP in vswitch subnet
    wireguard_addr   = string           # CIDR
    vlan_id          = number           # vSwitch VLAN ID
    install_disk     = optional(string) # falls back to var.install_disk
    network_interface = optional(string, "eth0") # physical NIC name (e.g. enp41s0)
  }))
  default     = {}
  description = "Map of worker node name to public IP (existing dedicated server), private IP in vswitch subnet, WireGuard CIDR, and vSwitch VLAN ID"
}

variable "pod_cidr" {
  type        = string
  default     = "10.244.0.0/16"
  description = "Pod CIDR — included in laptop wg AllowedIPs so cluster pod IPs route through the tunnel"
}

variable "service_cidr" {
  type        = string
  default     = "10.96.0.0/12"
  description = "Service CIDR — included in laptop wg AllowedIPs so cluster Service IPs route through the tunnel"
}

variable "lb_cidr" {
  type        = string
  default     = "10.50.0.0/24"
  description = "Cilium LB IP pool CIDR — included in laptop wg AllowedIPs so LoadBalancer IPs route through the tunnel"
}

variable "wireguard_clients" {
  type = object({
    public_key = string
    address    = string # CIDR e.g. 10.25.0.100/32
  })
  description = "WireGuard clients — public key and WireGuard address"
}

variable "wireguard_node_private_keys" {
  type        = map(string)
  sensitive   = true
  description = "Per-node WireGuard private keys, keyed by node name. Embedded in each node's wg0 interface config."
}

variable "wireguard_node_public_keys" {
  type        = map(string)
  description = "Per-node WireGuard public keys, keyed by node name. Used in the laptop wg0.conf."
}
