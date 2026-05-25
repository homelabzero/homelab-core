# Homelab

Personal homelab Kubernetes cluster — Talos Linux on Hetzner Cloud, accessed via WireGuard VPN, with Cilium CNI.

## Network

WireGuard VPN — `10.25.0.0/24`

| IP           | Host        |
| ------------ | ----------- |
| 10.25.0.3    | talos-cp-1  |
| 10.25.0.4    | talos-cp-2  |
| 10.25.0.5    | talos-cp-3  |
| 10.25.0.6    | talos-w-1   |
| 10.25.0.100  | MacBook     |

Hetzner private network — `10.20.0.0/16`

| Subnet          | Purpose                              |
| --------------- | ------------------------------------ |
| 10.20.0.0/24    | Cloud control planes                 |
| 10.20.1.0/24    | vSwitch — bare-metal worker          |

## Docs

0. [Infrastructure](docs/00-infrastructure.md)
1. [Laptop Setup](docs/01-laptop-setup.md)
2. [OpenTofu Backend](docs/02-opentofu-backend.md)
3. [Dedicated Server](docs/03-dedicated-server.md)
4. [WireGuard VPN](docs/04-wireguard.md)
5. [Talos Cluster](docs/05-talos-cluster.md)
6. [Cilium](docs/06-cilium.md)
