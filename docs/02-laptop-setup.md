# 02 - Laptop Setup

## Install Tools

```bash
brew install talosctl kubectl helm cilium-cli opentofu ansible
```

## WireGuard

Install from the [Mac App Store](https://apps.apple.com/app/wireguard/id1451685025).

## SSH Config

```ini
# ~/.ssh/config
Host homelab
    HostName 10.25.0.1
    User root
    IdentityFile ~/.ssh/homelab
```
