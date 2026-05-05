node_name     = "pve"
talos_version = "1.13.0"

sdn_zone        = "homelab"
sdn_vnet        = "internal"
subnet_cidr     = "10.50.0.0/24"
gateway         = "10.50.0.254"
dns_ip          = "10.50.0.1"
dhcp_dns_server = "10.50.0.1" # placeholder — Talos uses `nameservers` from machine config, not DHCP DNS

dhcp_range_start = "10.50.0.20"
dhcp_range_end   = "10.50.0.50"

nameservers = ["10.50.0.1"]

ssh_public_key_file = "~/.ssh/homelab.pub"

controlplane_name = "talos-cp-1"
worker_nodes      = ["talos-worker-1", "talos-worker-2"]
