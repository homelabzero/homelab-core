# Homelab

Personal homelab infrastructure built on Proxmox (Hetzner Cloud), accessed via WireGuard VPN, with Kubernetes via Talos Linux + Cilium.

## Network

WireGuard VPN — `10.25.0.0/24`

| IP          | Host     |
| ----------- | -------- |
| 10.25.0.1   | Proxmox  |
| 10.25.0.2   | MacBook  |

Internal LAN — `10.50.0.0/24` (Proxmox SDN: zone `homelab`, vnet `internal`)

| IP          | Host                    |
| ----------- | ----------------------- |
| 10.50.0.1   | PowerDNS (LXC 100)      |
| 10.50.0.20+ | Talos nodes (DHCP/IPAM) |
| 10.50.0.254 | Proxmox (gateway)       |

## Docs

0. [Hardware](docs/00-hardware.md)
1. [Proxmox Setup](docs/01-proxmox-setup.md)
2. [Laptop Setup](docs/02-laptop-setup.md)
3. [WireGuard VPN](docs/03-wireguard.md)
4. [OpenTofu Backend](docs/04-opentofu-backend.md)
5. [OpenTofu Proxmox Provider](docs/05-opentofu-proxmox.md)
6. [PowerDNS](docs/06-powerdns.md)
7. [Talos Cluster](docs/07-talos-cluster.md)
