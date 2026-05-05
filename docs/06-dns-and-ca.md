# 06 - DNS and Certificate Authority

PowerDNS and step-ca both run on the DNS LXC (`10.50.0.1`, container 100), provisioned in [step 05](05-opentofu-proxmox.md). Both are configured via Ansible.

Why on the LXC, not in the cluster: both are foundational infrastructure that must survive cluster rebuilds. PowerDNS resolves names that Talos itself depends on at boot. The step-ca root key, if it lived in the cluster, would be lost on `tofu destroy` — and every previously issued cert would become untrusted, requiring a fresh root install on every device.

**Talos depends on PowerDNS**, so PowerDNS must be up before [step 07](07-talos-cluster.md). step-ca can be applied any time after the LXC exists.

## Architecture

| Component | Port | Purpose |
|---|---|---|
| pdns-recursor | 53 | Resolves all DNS queries; forwards `.homelab` to local authoritative, everything else upstream |
| pdns (authoritative) | 5300 (loopback) | SQLite-backed authoritative server for the `homelab.` zone |
| pdns webserver/API | 8081 | HTTP API used by ExternalDNS and `curl` for record management |
| step-ca | 9000 | Private CA — signs certs requested by cert-manager in the cluster |

Clients (Talos nodes, pods) talk to the recursor on port 53. The authoritative server is loopback-only. cert-manager (in the cluster) talks to step-ca on `https://10.50.0.1:9000` via the step-issuer plugin.

## Prerequisites

- Ansible installed locally
- Three secrets generated and saved in your password manager:
  - `PDNS_API_KEY` — PowerDNS HTTP API auth
  - `STEP_CA_PASSWORD` — encrypts the CA root key at rest
  - `STEP_CA_PROVISIONER_PASSWORD` — used by cert-manager to authenticate

## Apply

```bash
export PDNS_API_KEY=$(openssl rand -hex 32)
export STEP_CA_PASSWORD=$(openssl rand -hex 32)
export STEP_CA_PROVISIONER_PASSWORD=$(openssl rand -hex 32)

cd ansible
ansible-playbook playbooks/powerdns.yml
ansible-playbook playbooks/step-ca.yml
```

Ansible reaches the LXC through the WireGuard tunnel + ProxyJump on the Proxmox host, authenticating with the SSH key OpenTofu already injected.

Both playbooks are idempotent. Re-run PowerDNS any time config changes (zone name, upstream resolvers, API key rotation). step-ca's `step ca init` is gated by `creates:` — it only runs once.

## Verify

### PowerDNS

```bash
# Public DNS through recursor
dig @10.50.0.1 example.com +short

# Local zone exists
dig @10.50.0.1 SOA homelab. +short

# API works
curl -s -H "X-API-Key: $PDNS_API_KEY" \
  http://10.50.0.1:8081/api/v1/servers/localhost/zones | jq
```

### step-ca

```bash
# Service is up
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 \
  "systemctl is-active step-ca && systemctl is-enabled step-ca"

# Health endpoint (insecure — root not trusted on the LXC)
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 \
  "curl -sk https://10.50.0.1:9000/health"
# expect: {"status":"ok"}

# Provisioner exists with the expected name
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 \
  "STEPPATH=/etc/step-ca step ca provisioner list"
```

## Trust the step-ca root on your Mac

Do this once. All browsers on your Mac will then trust `*.homelab` certs automatically.

```bash
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 \
  "cat /etc/step-ca/certs/root_ca.crt" > /tmp/homelab-root-ca.crt

sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain /tmp/homelab-root-ca.crt

# After this, /health works without -k from your Mac
curl https://10.50.0.1:9000/health
```

## Get values needed later by cert-manager

```bash
# Root CA fingerprint
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 \
  "STEPPATH=/etc/step-ca step certificate fingerprint /etc/step-ca/certs/root_ca.crt"
```

The provisioner password is whatever you set as `STEP_CA_PROVISIONER_PASSWORD` — store it; cert-manager will need it as a Kubernetes Secret.

## List PowerDNS records

```bash
# Via pdnsutil on the LXC
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 pdnsutil list-zone homelab.

# Via API
curl -s -H "X-API-Key: $PDNS_API_KEY" \
  http://10.50.0.1:8081/api/v1/servers/localhost/zones/homelab. | jq '.rrsets[]'
```

## Continue

Once both services answer their respective verifications, continue with [Talos Cluster](07-talos-cluster.md). The cluster's resolver is configured as `10.50.0.1`, so PowerDNS must be answering before Talos bootstraps.

## Troubleshooting

### step-ca fails to start

```bash
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 "journalctl -u step-ca -n 50"
```

Common causes:
- Wrong password in `/etc/step-ca/password.txt` — rerun the playbook with the correct `STEP_CA_PASSWORD`
- Port 9000 already in use — `ss -tlnp | grep 9000`

### Re-initialize step-ca (wipe and start over)

```bash
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 \
  "systemctl stop step-ca && rm -rf /etc/step-ca/config /etc/step-ca/certs /etc/step-ca/secrets /etc/step-ca/db"
ansible-playbook playbooks/step-ca.yml
```

Then re-trust the new root cert on all devices.

## Notes

- **pdns-recursor 5.x uses YAML config (`recursor.yml`)** with snake_case keys. Old `recursor.conf` (key=value) is deprecated.
- **pdns-auth 4.9 still uses `pdns.conf`** (key=value). YAML support exists but `pdnsutil` doesn't read it.
- **All secrets live in env vars** — the playbooks pull via `lookup('env', ...)`. No vaults, no committed secrets.
- The `homelab.` zone is created automatically; records will be managed by ExternalDNS once it's deployed.
- step-ca creates a JWK provisioner named `cert-manager` during init. cert-manager will reference this provisioner when it's deployed in the cluster.
