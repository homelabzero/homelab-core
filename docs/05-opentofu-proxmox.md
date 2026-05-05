# 05 - OpenTofu Proxmox Provider

OpenTofu provisions the Proxmox infrastructure: SDN network, the DNS LXC, and the Talos VMs (which boot into maintenance mode awaiting Talos config).

## Generate an API Token

In Proxmox UI → Datacenter → Permissions → API Tokens → Add:

- User: `root@pam`
- Token ID: `tofu`
- Description: `OpenTofu`
- Privilege Separation: unchecked (inherit full user permissions)

Save the secret — it's only shown once.

Export it in your shell (single quotes — `!` triggers zsh history expansion):

```bash
export PROXMOX_VE_API_TOKEN='root@pam!tofu=<YOUR_API_TOKEN>'
```

The provider reads `PROXMOX_VE_API_TOKEN` automatically.

## Hetzner Firewall

The Hetzner Robot firewall is stateless. Outbound packets are allowed, but responses are blocked unless explicitly permitted. Add these rules **before** the final discard rule:

| # | Protocol | Source port | Dest port | Action |
|---|---|---|---|---|
| 1 | ICMP | any | any | accept |
| 2 | TCP | any | any | accept (TCP flag: ACK) |
| 3 | UDP | 53 | any | accept |
| 4 | UDP | 123 | any | accept |
| 5 | UDP | any | 51820 | accept (WireGuard) |

## Host Prerequisites

The Proxmox SDN DHCP plugin uses `dnsmasq`. Install it on the host:

```bash
ssh homelab
apt-get install -y dnsmasq
systemctl disable --now dnsmasq  # SDN runs per-zone instances (dnsmasq@<zone>)
```

The WireGuard client must be able to route to `10.50.0.0/24` through the Proxmox host:
- `AllowedIPs` on the client includes `10.50.0.0/24`
- No conflicting bridge IP on the Proxmox host (`ip route get 10.50.0.x` should show `dev internal`)

## Apply

```bash
cd opentofu/infrastructure
tofu apply -target=module.proxmox
```

This creates:

- **SDN** zone `homelab`, vnet `internal`, subnet `10.50.0.0/24` (DHCP `10.50.0.20–50`, NAT)
- **DNS LXC** (`10.50.0.1`, container 100, Debian 13) with `~/.ssh/homelab.pub` injected into root
- **Talos VMs** (110/111/112) booted from a custom Image Factory ISO with the `qemu-guest-agent` extension; they sit in maintenance mode until Talos config is pushed in [step 07](07-talos-cluster.md)

Continue with [PowerDNS](06-powerdns.md) — Talos can't bootstrap without DNS.

## Troubleshooting

### MacBook can't reach VMs (network unreachable)

Check `ip route get 10.50.0.x` on the Proxmox host. If it shows `dev vmbr1` instead of `dev internal`, a stale bridge is stealing the route:

```bash
ip addr del 10.50.0.254/24 dev vmbr1
```

### SDN not applied

```bash
pvesh get /cluster/sdn/zones/homelab   # should show state: available
systemctl status dnsmasq@homelab
```
