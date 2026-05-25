variable "cluster_name" {
  type    = string
  default = "homelab"
}

variable "talos_version" {
  type        = string
  description = "Talos version (e.g. 1.13.0). Bump via talosctl upgrade afterwards."
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "talos_hetzner_iso" {
  type        = string
  description = "Public Hetzner ISO name (e.g. hcloud-v1-12-4.amd64.iso) — Talos hcloud-flavored image"
}

# ---- Cloud control planes ----

variable "controlplane_nodes" {
  type = map(object({
    location       = string
    server_type    = string
    private_ip     = string           # in cloud_subnet_cidr
    wireguard_addr = string           # CIDR e.g. 10.25.0.3/24
    install_disk   = optional(string) # override; falls back to var.install_disk
  }))
  description = "Map of CP node name to Hetzner Cloud location, server type, static private IP, and WireGuard CIDR address"
}

# ---- Bare-metal worker (existing dedicated server) ----

variable "worker_nodes" {
  type = map(object({
    public_ip         = string # existing dedicated server IP
    private_ip        = string # in vswitch_subnet_cidr
    wireguard_addr    = string
    vlan_id           = number           # vSwitch VLAN ID (assigned in Robot)
    install_disk      = optional(string) # override; falls back to var.install_disk
    network_interface = optional(string, "eth0") # physical NIC name (e.g. enp41s0)
  }))
  default = {}
}

# ---- Hetzner Robot vSwitch ----

variable "vswitch_id" {
  type        = number
  description = "Hetzner Robot vSwitch ID — vSwitch must exist with the dedicated server attached"
}

variable "network_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "lb_cidr" {
  type    = string
  default = "10.50.0.0/24"
  description = "Cilium LB IP pool CIDR — routed through the WireGuard tunnel to the laptop"
}

variable "cloud_subnet_cidr" {
  type    = string
  default = "10.20.0.0/24"
}

variable "vswitch_subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

# ---- WireGuard ----

# Generate per-node keypairs once with `wg genkey | tee /tmp/k | wg pubkey`,
# then paste them into secrets.tfvars. Map keys must match controlplane_nodes
# and worker_nodes names.
variable "wireguard_node_private_keys" {
  type        = map(string)
  sensitive   = true
  description = "Per-node WireGuard private keys, keyed by node name. Loaded from secrets.tfvars."
}

variable "wireguard_node_public_keys" {
  type        = map(string)
  description = "Per-node WireGuard public keys, keyed by node name. Loaded from secrets.tfvars. Used in the laptop wg0.conf."
}

variable "laptop_wireguard" {
  type = object({
    public_key = string
    address    = string # CIDR e.g. 10.25.0.100/32
  })
  description = "Laptop WireGuard peer — TF doesn't have the private key. Address goes into wg0.conf, public key gets added to every node."
}

# ---- Cloudflare / DNS ----

variable "cloudflare_zone" {
  type        = string
  description = "Cloudflare zone (apex domain), e.g. homelab0.xyz"
}

variable "internal_subdomain" {
  type        = string
  description = "Subdomain used for internal services, e.g. internal.homelab0.xyz. external-dns is restricted to this; the wildcard cert covers *.<this>."
}

variable "api_hostname" {
  type        = string
  description = "Hostname for the Kubernetes API, e.g. api.internal.homelab0.xyz. Cloudflare A records point this at every CP public IP."
}

variable "acme_email" {
  type        = string
  description = "Email registered with Let's Encrypt"
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token (Zone:DNS:Edit on the homelab zone). Pass via TF_VAR_cloudflare_api_token. Same token can also be set as CLOUDFLARE_API_TOKEN for the cloudflare provider itself."
}

# ---- Misc ----

variable "nameservers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

variable "install_disk" {
  type        = string
  default     = "/dev/sda"
  description = "Disk Talos installs to. Same on cloud and bare-metal nodes."
}

variable "bootstrap_complete" {
  type        = bool
  default     = false
  description = "Set to true once the cluster is up and WireGuard works end-to-end. Locks the Hetzner firewall down to UDP 51820 only — Talos API (50000) and kube-apiserver (6443) become reachable only via WG."
}
