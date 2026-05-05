variable "node_name" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "sdn_zone" {
  type        = string
  description = "SDN zone ID (8 chars max, alphanumeric)"
}

variable "sdn_vnet" {
  type        = string
  description = "SDN VNet ID — also becomes the bridge name (8 chars max, alphanumeric)"
}

variable "subnet_cidr" {
  type        = string
  description = "Internal subnet CIDR, e.g. 10.50.0.0/24"
}

variable "gateway" {
  type        = string
  description = "Gateway IP for the internal subnet"
}

variable "dns_ip" {
  type        = string
  description = "Static IP for the DNS LXC"
}

variable "dhcp_dns_server" {
  type        = string
  description = "DNS server handed out by SDN DHCP (must be within subnet_cidr — SDN rejects out-of-subnet IPs)"
}

variable "dhcp_range_start" {
  type        = string
  description = "Start of DHCP range — leases are sticky per MAC via Proxmox IPAM"
}

variable "dhcp_range_end" {
  type        = string
  description = "End of DHCP range"
}

variable "ssh_public_key_file" {
  type        = string
  description = "Path to SSH public key file to inject into the DNS LXC root account"
}
