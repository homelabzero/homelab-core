variable "node_name" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "sdn_zone" {
  type = string
}

variable "sdn_vnet" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "gateway" {
  type = string
}

variable "dns_ip" {
  type = string
}

variable "dhcp_dns_server" {
  type = string
}

variable "dhcp_range_start" {
  type = string
}

variable "dhcp_range_end" {
  type = string
}

variable "controlplane_name" {
  type = string
}

variable "worker_nodes" {
  type        = list(string)
  description = "List of worker node names"
}

variable "nameservers" {
  type = list(string)
}

variable "ssh_public_key_file" {
  type = string
}
