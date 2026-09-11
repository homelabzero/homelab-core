# Per-node hardware identity from topf.yaml node data.
# Resolve the cluster endpoint locally so on-host controllers don't need NetBird DNS.
machine:
  install:
    diskSelector:
      serial: "{{ .Node.Data.systemDiskSerial }}"
  network:
    interfaces:
      - deviceSelector:
          hardwareAddr: "{{ .Node.Data.mac }}"
        dhcp: true
    extraHostEntries:
      - ip: 127.0.0.1
        aliases:
          - {{ .Node.Host }}.netbird.cloud
