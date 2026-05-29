# 03 - Dedicated Server

One-time bare-metal prep for the Hetzner Robot server. Done once per node —
Talos persists across reboots after install.

## Build the Talos Image

Talos boots from a Hetzner-rescue `dd`. The image is a metal image built by
the Talos Image Factory with the `siderolabs/netbird` system extension baked
in — that's what gives the node NetBird connectivity from the moment it
boots.

Compute the schematic ID and image URL:

```bash
ID=$(curl -sS -X POST -H "Content-Type: application/yaml" \
  --data-binary @- https://factory.talos.dev/schematics <<'EOF' | jq -r .id
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/netbird
EOF
)

VER=$(awk -F'"' '/^talos_version/ {print $2}' \
  opentofu/infrastructure/terraform.tfvars)

echo "https://factory.talos.dev/image/$ID/v$VER/metal-amd64.raw.xz"
```

The Talos OpenTofu module recomputes the same ID at plan time for the
installer image, so the running OS and the on-disk installer always match.

## Install Talos (Rescue System)

1. In [Hetzner Robot](https://robot.hetzner.com) → Server → Reset → activate
   rescue system.
2. SSH in and dd the metal image to disk:

   ```bash
   wget -O /tmp/talos.raw.xz "<image_url_from_above>"
   xz -d -c /tmp/talos.raw.xz | dd of=/dev/nvme0n1 bs=4M status=progress && sync
   reboot
   ```

3. The server reboots into Talos maintenance mode on its public IP. The Talos
   API is reachable on port 50000.

## Robot Firewall

The cluster API (6443) and Talos API (50000) are publicly listening. Apply
Robot firewall rules at your discretion — NetBird is *not* a firewall for the
node itself, only the access path for the laptop.

Recommended minimum:

| # | Protocol | Source IP    | Dest port | Action                  |
| - | -------- | ------------ | --------- | ----------------------- |
| 1 | ICMP     | any          | any       | accept                  |
| 2 | TCP      | any          | any       | accept (TCP flag: ACK)  |
| 3 | UDP      | any          | 51820     | accept (NetBird WG)     |

Locking down 50000/6443 to only NetBird overlay IPs is possible but loses
the "rescue from anywhere" property if NetBird ever breaks. Trade-off is
yours.

## Per-Node Values for tfvars

After install, record in `opentofu/infrastructure/terraform.tfvars`:

```hcl
nodes = {
  talos-1 = {
    public_ip         = "<server public IP>"
    install_disk      = "/dev/nvme0n1"
    network_interface = "enp41s0"  # check with `ip link` from rescue
  }
}
```
