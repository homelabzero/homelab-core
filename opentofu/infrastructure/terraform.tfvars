cluster_name       = "homelab"
talos_version      = "1.13.0"
kubernetes_version = "1.35.5"                   # capped at 1.35.x because the Hetzner ISO runs Talos 1.12.4
talos_hetzner_iso  = "hcloud-v1-12-4.amd64.iso" # Hetzner public Talos image (qemu-guest-agent included)

# Cloudflare DNS
cloudflare_zone    = "homelab0.xyz"
internal_subdomain = "internal.homelab0.xyz"
api_hostname       = "api.internal.homelab0.xyz"
acme_email         = "dmytro.rybak4@gmail.com"

# Hetzner Cloud control planes — one per eu-central location, CPX22.
# Private IPs allocated from cloud_subnet_cidr (default 10.20.0.0/24).
controlplane_nodes = {
  talos-cp-1 = { location = "nbg1", server_type = "cpx22", private_ip = "10.20.0.10", wireguard_addr = "10.25.0.3/24" }
  talos-cp-2 = { location = "fsn1", server_type = "cpx22", private_ip = "10.20.0.11", wireguard_addr = "10.25.0.4/24" }
  talos-cp-3 = { location = "hel1", server_type = "cpx22", private_ip = "10.20.0.12", wireguard_addr = "10.25.0.5/24" }
}

# Bare-metal worker on the existing Hetzner dedicated server.
# - public_ip : the server's existing public IP
# - private_ip: static IP in vswitch_subnet_cidr (avoid the .1 gateway)
# - vlan_id   : VLAN ID assigned in Robot when creating the vSwitch
worker_nodes = {
  talos-w-1 = {
    public_ip         = "148.251.156.11"
    private_ip        = "10.20.1.10"
    wireguard_addr    = "10.25.0.6/24"
    vlan_id           = 4000
    install_disk      = "/dev/nvme0n1"
    network_interface = "enp41s0"
  }
}

vswitch_id = 81327

bootstrap_complete = true

# Laptop WG peer — public key only (private key stays on the laptop).
laptop_wireguard = {
  public_key = "RcXSQLVbmsXZLyiVphXpzZyFqNh5UvCr+awKMwdhEQ8="
  address    = "10.25.0.100/32"
}
