# 01 - Laptop Setup

## Install Tools

```bash
brew install talosctl kubectl helm cilium-cli opentofu
```

## NetBird Client

The laptop's only path to the cluster is NetBird. Install the GUI from
[netbird.io](https://netbird.io/download) or use the CLI:

```bash
netbird up --setup-key <YOUR_KEY>
```

Get a setup key at [app.netbird.io](https://app.netbird.io) → Setup Keys. The
same key is used by the cluster nodes (reusable key).

Verify the laptop peer is connected:

```bash
netbird status
```

You should see your peers and `Management: Connected`.
