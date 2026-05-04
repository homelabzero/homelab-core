# Homelab

Personal homelab infrastructure built on Proxmox (Hetzner Cloud), accessed via WireGuard VPN, with Kubernetes planned via Talos.

## Network

WireGuard VPN — `10.25.0.0/24`

| IP          | Host     |
| ----------- | -------- |
| 10.25.0.1   | Proxmox  |
| 10.25.0.2   | MacBook  |

Internal LAN — `10.50.0.0/24` (bridge `vmbr1`)

| IP          | Host                 |
| ----------- | -------------------- |
| 10.50.0.1   | PowerDNS (LXC 100)   |
| 10.50.0.10  | Talos control plane  |
| 10.50.0.11  | Talos worker 1       |
| 10.50.0.12  | Talos worker 2       |
| 10.50.0.254 | Proxmox (gateway)    |

## Docs

0. [Hardware](docs/00-hardware.md)
1. [Proxmox Setup](docs/01-proxmox-setup.md)
2. [Laptop Setup](docs/02-laptop-setup.md)
3. [WireGuard VPN](docs/03-wireguard.md)
4. [OpenTofu Backend](docs/04-opentofu-backend.md)
5. [OpenTofu Proxmox Provider](docs/05-opentofu-proxmox.md)
6. [Talos Cluster](docs/06-talos-cluster.md)
