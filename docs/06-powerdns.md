# 06 - PowerDNS

PowerDNS provides DNS for the entire homelab — both forwarding public queries upstream and serving the internal `homelab.` zone. It runs on the DNS LXC (`10.50.0.1`, container 100), already provisioned in [step 05](05-opentofu-proxmox.md). **Talos depends on it**, so PowerDNS comes up next.

## Architecture

| Component | Port | Purpose |
|---|---|---|
| pdns-recursor | 53 | Resolves all DNS queries; forwards `.homelab` to local authoritative, everything else upstream |
| pdns (authoritative) | 5300 (loopback) | SQLite-backed authoritative server for the `homelab.` zone |
| pdns webserver/API | 8081 | HTTP API used by ExternalDNS and `curl` for record management |

Clients (Talos nodes, pods) talk to the recursor on port 53. The authoritative server is loopback-only.

## Prerequisites

- Ansible installed locally
- A randomly generated PowerDNS API key (stored in your password manager)

## Apply

```bash
export PDNS_API_KEY=$(openssl rand -hex 32)   # generate once, save it
cd ansible
ansible-playbook playbooks/powerdns.yml
```

Ansible reaches the LXC through the WireGuard tunnel + ProxyJump on the Proxmox host, authenticating with the SSH key OpenTofu already injected.

The playbook is idempotent — re-run it any time config changes (zone name, upstream resolvers, API key rotation).

## Verify

```bash
# Public DNS through recursor
dig @10.50.0.1 example.com +short

# Local zone exists
dig @10.50.0.1 SOA homelab. +short

# API works
curl -s -H "X-API-Key: $PDNS_API_KEY" \
  http://10.50.0.1:8081/api/v1/servers/localhost/zones | jq
```

Once these all return successfully, continue with [Talos Cluster](07-talos-cluster.md) — the cluster's resolver is configured as `10.50.0.1`, so PowerDNS must be answering before Talos bootstraps.

## List records

```bash
# Via pdnsutil on the LXC
ssh -i ~/.ssh/homelab -J homelab root@10.50.0.1 pdnsutil list-zone homelab.

# Via API
curl -s -H "X-API-Key: $PDNS_API_KEY" \
  http://10.50.0.1:8081/api/v1/servers/localhost/zones/homelab. | jq '.rrsets[]'
```

## Notes

- **pdns-recursor 5.x uses YAML config (`recursor.yml`)** with snake_case keys. Old `recursor.conf` (key=value) is deprecated.
- **pdns-auth 4.9 still uses `pdns.conf`** (key=value). YAML support exists but `pdnsutil` doesn't read it.
- **API key lives in `$PDNS_API_KEY`** — pulled by the playbook via `lookup('env', ...)`. No vault, no committed secrets.
- The `homelab.` zone is created automatically; records will be managed by ExternalDNS once it's deployed.
