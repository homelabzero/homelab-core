# 04 - WireGuard

Node WireGuard keys are generated manually once and stored in `secrets.tfvars`. The laptop side is managed entirely via the WireGuard Mac App.

## Generate Node Keypairs (one-time)

Generate one keypair per node and store them in `opentofu/infrastructure/secrets.tfvars`:

```bash
wg genkey | tee /tmp/k | wg pubkey  # run once per node
```

```hcl
wireguard_node_private_keys = {
  talos-cp-1 = "<private-key>"
  talos-cp-2 = "<private-key>"
  talos-cp-3 = "<private-key>"
  talos-w-1  = "<private-key>"
}

wireguard_node_public_keys = {
  talos-cp-1 = "<public-key>"
  talos-cp-2 = "<public-key>"
  talos-cp-3 = "<public-key>"
  talos-w-1  = "<public-key>"
}
```

## Generate Laptop Keypair (one-time)

Open the WireGuard Mac App → **Add Empty Tunnel**. It generates a keypair and displays the public key.

Copy the public key into `opentofu/infrastructure/terraform.tfvars`:

```hcl
laptop_wireguard = {
  public_key = "<your-public-key>"
  address    = "10.25.0.100/32"
}
```

## Configure the Laptop Tunnel

After `tofu apply`, get the peer configs:

```bash
cd opentofu/infrastructure
tofu output -raw wireguard_laptop_config
```

Copy the `[Peer]` blocks from the output into the tunnel config in the WireGuard Mac App, then toggle the tunnel on.

## Verify

```bash
sudo wg show
```

Each node should appear as a peer with a recent `latest handshake`.
