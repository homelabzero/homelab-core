# 02 - Dedicated Server

One-time bare-metal prep for the Hetzner Robot server. Done once per node —
Talos persists across reboots after install.

## Build the Talos Image

Talos boots from a Hetzner-rescue `dd`. The image is a metal image built by
the Talos Image Factory with the `siderolabs/netbird` system extension baked
in — that's what gives the node NetBird connectivity from the moment it
boots.

The schematic is defined in `talos/schematic.yaml`. Get its ID and build the
image URL (`talos_version` from `talos/topf.yaml`):

```bash
cd talos
ID=$(topf schematicids)
VER=$(awk '/^talosVersion:/ {print $2}' topf.yaml)
echo "https://factory.talos.dev/image/$ID/v$VER/metal-amd64.raw.xz"
```

topf derives the same ID for the installer image, so the running OS and the
on-disk installer always match.

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

## Per-Node Values for topf.yaml

After install, record the node under `nodes` in `talos/topf.yaml`:

```yaml
nodes:
  - host: talos-1
    ip: 148.251.156.11   # public IP — topf's connection target
    role: control-plane
```

The install disk (`/dev/nvme0n1`) and interface (`enp41s0`) are set in
`talos/all/machine.yaml`; check them from rescue with `lsblk` / `ip link`.
