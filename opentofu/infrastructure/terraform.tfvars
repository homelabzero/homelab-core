node_name       = "pve"
talos_version   = "1.13.0"
internal_bridge = "vmbr1"
gateway         = "10.50.0.254"
dns_ip          = "10.50.0.1"

nameservers = ["10.50.0.254"]

controlplane_ip = "10.50.0.10"

worker_nodes = {
  "talos-worker-1" = "10.50.0.11"
  "talos-worker-2" = "10.50.0.12"
}
