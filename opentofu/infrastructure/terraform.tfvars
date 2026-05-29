cluster_name       = "homelab"
talos_version      = "1.13.0"
kubernetes_version = "1.36.1"

api_hostname = "talos-1.netbird.cloud"

nodes = {
  talos-1 = {
    public_ip         = "148.251.156.11"
    install_disk      = "/dev/nvme0n1"
    network_interface = "enp41s0"
  }
}
