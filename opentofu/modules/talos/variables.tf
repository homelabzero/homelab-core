###########################################################################
# Cluster
###########################################################################

variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
}

variable "talos_version" {
  type        = string
  description = "Talos version contract (e.g. 1.13.0). Used for installer image tag and machine config contract."
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Kubernetes version. If null, the Talos provider's default is used."
}

variable "cluster_endpoint" {
  type        = string
  description = "kube-apiserver hostname (no scheme, no port). Embedded in machine config and kubeconfig."
}

variable "install_disk" {
  type        = string
  default     = "/dev/sda"
  description = "Default install disk; nodes may override via the install_disk field in var.nodes."
}

###########################################################################
# Nodes
###########################################################################

variable "nodes" {
  type = map(object({
    public_ip         = string
    install_disk      = optional(string)
    network_interface = optional(string, "eth0") # physical NIC name (e.g. enp41s0 on Hetzner dedicated)
  }))
  description = "Map of node name to its public IP, install disk, and physical NIC. Each node is a combined control-plane + worker (allowSchedulingOnControlPlanes=true). Scale to HA by adding entries."
}

###########################################################################
# NetBird
###########################################################################

variable "netbird_setup_key" {
  type        = string
  sensitive   = true
  description = "NetBird Cloud setup key (UUID). Generated at app.netbird.io → Setup Keys (reusable). Loaded via secrets.tfvars."
}

variable "netbird_management_url" {
  type        = string
  default     = "https://api.netbird.io:443"
  description = "NetBird management server URL. Default is NetBird Cloud; override for self-hosted control plane."
}
