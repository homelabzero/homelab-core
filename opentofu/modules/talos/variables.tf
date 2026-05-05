variable "cluster_name" {
  type    = string
  default = "homelab-admin"
}

variable "controlplane_name" {
  type        = string
  description = "Name of the control plane node (key in node_initial_ips)"
}

variable "worker_nodes" {
  type        = set(string)
  description = "Set of worker node names (keys in node_initial_ips)"
}

variable "node_initial_ips" {
  type        = map(string)
  description = "Map of node name to DHCP-assigned IP (from QEMU agent)"
}

variable "install_disk" {
  type    = string
  default = "/dev/sda"
}

variable "schematic_id" {
  type        = string
  description = "Talos factory schematic ID (for installer image)"
}

variable "talos_version" {
  type        = string
  description = "Talos version (e.g. 1.13.0) — must match the boot ISO"
}

variable "nameservers" {
  type = list(string)
}
