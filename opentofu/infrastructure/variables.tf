variable "node_name" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "internal_bridge" {
  type = string
}

variable "gateway" {
  type = string
}

variable "dns_ip" {
  type = string
}

variable "controlplane_ip" {
  type = string
}

variable "worker_nodes" {
  type        = map(string)
  description = "Map of worker name to IP address"
}

variable "nameservers" {
  type = list(string)
}
