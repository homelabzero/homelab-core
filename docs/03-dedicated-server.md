# 03 - Dedicated Server

One-time setup for the Hetzner dedicated server (`talos-w-1`). Done once — Talos persists across reboots after installation.

## vSwitch

1. In [Hetzner Robot](https://robot.hetzner.com) → vSwitch → Create.
2. Attach the dedicated server to it.
3. Note the numeric ID and set it in `opentofu/infrastructure/terraform.tfvars`:
   ```hcl
   vswitch_id = 81327
   ```

## Install Talos (Rescue System)

1. Boot the server into the [Hetzner rescue system](https://robot.hetzner.com) (Robot → Server → Reset → Activate rescue system).
2. SSH in and write the Talos metal image to disk:

```bash
wget -O /tmp/talos.raw.xz https://github.com/siderolabs/talos/releases/download/v1.13.0/metal-amd64.raw.xz
xz -d -c /tmp/talos.raw.xz | dd of=/dev/nvme0n1 bs=4M status=progress && sync
reboot
```

3. The server reboots into Talos maintenance mode. It will accept machine config on port 50000 of its public IP.

## Robot Firewall

The Hetzner Robot firewall is **stateless** — outbound is allowed but inbound responses are blocked unless explicitly permitted. Configure these rules before the final discard rule:

| # | Protocol | Source port | Dest port      | Action                  |
| - | -------- | ----------- | -------------- | ----------------------- |
| 1 | ICMP     | any         | any            | accept                  |
| 2 | TCP      | any         | any            | accept (TCP flag: ACK)  |
| 3 | UDP      | any         | 51820          | accept (WireGuard)      |
| 4 | TCP      | any         | 50000          | accept (Talos API)      |

Rule 6 can be removed once `bootstrap_complete = true` is applied in OpenTofu — after that, Talos API is only reachable over WireGuard.
