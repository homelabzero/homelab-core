# 05 - Talos Cluster

Kubernetes runs on [Talos Linux](https://www.talos.dev/). Cloud control planes boot from a Hetzner-hosted Talos ISO and receive their machine config via `user_data` on first boot.

## Architecture

| Node       | Role         | Location | IP (private) | IP (WireGuard) |
| ---------- | ------------ | -------- | ------------ | -------------- |
| talos-cp-1 | controlplane | nbg1     | 10.20.0.10   | 10.25.0.3      |
| talos-cp-2 | controlplane | fsn1     | 10.20.0.11   | 10.25.0.4      |
| talos-cp-3 | controlplane | hel1     | 10.20.0.12   | 10.25.0.5      |
| talos-w-1  | worker       | fsn1     | 10.20.1.10   | 10.25.0.6      |

## Prerequisites

Complete these one-time steps before applying:

- [Dedicated server setup](03-dedicated-server.md) — vSwitch, Talos installation on worker
- [WireGuard setup](04-wireguard.md) — node keypairs in `secrets.tfvars`, laptop public key in `terraform.tfvars`

## Apply

```bash
export HCLOUD_TOKEN=...
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_cloudflare_api_token=$CLOUDFLARE_API_TOKEN

cd opentofu/infrastructure
tofu init -backend-config=backend.hcl
tofu apply
```

OpenTofu:
- Creates the Hetzner Cloud network, subnets, vSwitch coupling, and firewall
- Boots three CPX22 VMs from the Hetzner Talos ISO with machine config injected via `user_data`
- Pushes Talos machine config to the bare-metal worker via its public IP
- Bootstraps etcd on the first control plane

## Get Credentials

```bash
tofu output -raw kubeconfig  > ~/.kube/homelab.config
tofu output -raw talosconfig > ~/.talos/config
```

For WireGuard, get the peer configs and add them to the Mac App tunnel — see [WireGuard setup](04-wireguard.md).

## Verify

```bash
KUBECONFIG=~/.kube/homelab.config kubectl get nodes
talosctl --talosconfig ~/.talos/config health --nodes 10.25.0.3
```

All nodes should be `Ready`. etcd should be healthy. Install [Cilium](06-cilium.md) next.

## Lock Down the Firewall

During bootstrap, TCP 50000 (Talos API) and 6443 (kube-apiserver) are open publicly so OpenTofu can push machine config. Once WireGuard is verified, close them:

1. Set `bootstrap_complete = true` in `terraform.tfvars`.
2. `tofu apply` — only the firewall rules change.

After this, the cluster is reachable only over WireGuard.
