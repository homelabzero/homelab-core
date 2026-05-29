# 05 - Talos Cluster

Single Talos node acting as combined control plane + worker, scaling to 3 by
adding entries to `nodes`. The cluster endpoint is a NetBird peer DNS name
(e.g. `talos-1.netbird.cloud`) and resolves only when NetBird is up on the
client.

## Prerequisites

- [Infrastructure](00-infrastructure.md), [Laptop](01-laptop-setup.md),
  [Backend](02-opentofu-backend.md), [Dedicated server](03-dedicated-server.md)
  all done.
- The node is in Talos maintenance mode on its public IP.
- `terraform.tfvars` has `nodes`, `api_hostname`, `talos_version`,
  `kubernetes_version`.
- `secrets.tfvars` exists with:

  ```hcl
  netbird_setup_key    = "00000000-0000-0000-0000-000000000000"
  cloudflare_api_token = "<token>"
  ```

  Setup key: app.netbird.io → Setup Keys (reusable).
  Cloudflare token: `Zone:DNS:Edit` on the homelab zone (used later by
  cert-manager / external-dns).

## Apply

```bash
cd opentofu/infrastructure
tofu init -backend-config=backend.hcl
tofu apply -var-file=secrets.tfvars
```

OpenTofu:
- Builds the Talos installer image URL from the Image Factory (NetBird
  extension baked in)
- Generates Talos PKI and machine config
- Pushes config to each node (creates the netbird ExtensionServiceConfig with
  the setup key)
- Bootstraps etcd on the first node
- Writes `~/.kube/homelab.kubeconfig` and `~/.talos/config`

## Cluster Endpoint and NetBird FQDN

On first enrollment NetBird gives the node a peer FQDN like
`talos-1.netbird.cloud`. After a reset, NetBird Cloud may suffix the new
enrollment (e.g. `talos-1-25-163.netbird.cloud`) because the prior peer is
still in the account.

To keep the endpoint stable across resets:

1. Delete the orphan peer in app.netbird.io → Peers **before** re-enrollment
   if possible, or
2. Rename the new peer to `talos-1` after enrollment.

If neither works, point `api_hostname` at whatever FQDN NetBird actually
assigned and `tofu apply` — the machine config re-applies (new SANs, new
`extraHostEntries`) and the kubeconfig auto-refreshes.

## Verify

```bash
KUBECONFIG=~/.kube/homelab.kubeconfig kubectl get nodes
talosctl --talosconfig ~/.talos/config -n <node_public_ip> health
```

Node will be `NotReady` until [Cilium](06-cilium.md) is installed.
