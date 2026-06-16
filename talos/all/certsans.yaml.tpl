# Add the node's NetBird FQDN to the Talos API cert SANs for stable talosctl access.
machine:
  certSANs:
    - {{ .Node.Host }}.netbird.cloud
