variable "cluster_name" {
  type    = string
  default = "homelab-admin"
}

variable "controlplane_ip" {
  type = string
}

variable "worker_nodes" {
  type        = map(string)
  description = "Map of worker name to IP address"
}

variable "gateway" {
  type    = string
  default = "10.50.0.254"
}

variable "install_disk" {
  type    = string
  default = "/dev/sda"
}

variable "nameservers" {
  type = list(string)
}
