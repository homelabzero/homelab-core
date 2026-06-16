# Per-node hostname; NetBird inherits it (NB_HOSTNAME unset in netbird.sops.yaml).
apiVersion: v1alpha1
kind: HostnameConfig
auto: "off"
hostname: {{ .Node.Host }}
