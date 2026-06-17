# 01 - Laptop Setup

## Install Tools

```bash
brew install talosctl kubectl helm cilium-cli hashicorp/tap/vault postfinance/tap/topf sops age
```

## NetBird Client

The laptop's only path to the cluster is NetBird. Install the GUI client from
[netbird.io/download](https://netbird.io/download) and log in through the
browser (SSO) — no setup key on the laptop (setup keys are only for headless
node enrollment).

Verify the peer is connected:

```bash
netbird status
```

You should see your peers and `Management: Connected`.
