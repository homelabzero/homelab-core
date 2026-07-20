# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Homelab Kubernetes on **Talos Linux** — one Hetzner dedicated server (combined CP+worker, scales 1→3), Cilium CNI (no kube-proxy), laptop access **only via NetBird** (`*.netbird.cloud`). Two layers:

- **`talos/`** — node config, rendered by [`topf`](https://postfinance.github.io/topf/) + SOPS/age. Patches layer `all/` → role → `node/<host>/`; `*.sops.yaml` are encrypted (committed for DR), `*.yaml.tpl` are Go-templated — a file is one or the other. `output/` is gitignored (contains secrets).
- **`kubernetes/`** — Argo CD **app-of-apps**: `app-of-apps.yaml` is the root; `argocd-apps/*.yaml` is one `Application` per component (Helm values inline, optional second source → `kubernetes/<component>/` for raw manifests). All apps prune+selfHeal: **the cluster is a pure function of git — edit manifests, never `kubectl edit` live objects.** Push to `main` = deploy.

`archive/` is the dead OpenTofu/Proxmox setup (gitignored) — ignore any `tofu`/`hcloud` references. Numbered guides in `docs/` cover bring-up; read them before non-trivial cluster changes.

## Working on it

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
export KUBECONFIG=~/.kube/homelab.kubeconfig

cd talos && topf render               # validate node config (offline, safe)
talosctl apply-config --file talos/output/talos-1.yaml  # day-2 config push (over NetBird; `topf apply` is first-provision only)
sops talos/all/netbird.sops.yaml      # edit encrypted files in place

kubectl -n argocd get applications    # sync/health of every component
```

**New component** = add `kubernetes/argocd-apps/<name>.yaml` with the right `sync-wave` (grep existing apps; shape: cilium 0 → storage 1 → db/vault/vso 2 → cert-manager 3 → platform 4 → UI/observability 5) + optional `kubernetes/<name>/` manifests. Needs a secret? Add a `VaultStaticSecret` + `vault-auth` SA in its namespace and seed the Vault path — the path↔manifest table is in `docs/05-bootstrap.md` step 3; keys must match verbatim.

**CI**: PRs touching `argocd-apps/` get a rendered-manifest diff as a PR comment; Renovate auto-merges minor/patch chart bumps gated on that check.

## Architecture facts you can't grep

- **Secrets**: Vault (hand-unsealed, seals on every reboot) → VSO → K8s Secrets. VSO resolves the `vault-auth` SA in the *consuming* namespace. A sealed Vault stalls sync-wave 2 and gates all secret-consuming waves — that stall is intentional, not a bug.
- **Exposure** is chosen by HTTPRoute `parentRef`: `gateway-internal` (`*.internal.homelab0.xyz`, VIP `10.60.0.1`, NetBird-only — the default) or `gateway-public` (`*.homelab0.xyz`, outbound-only Cloudflare Tunnel, no inbound ports). Public = HTTPRoute on `gateway-public` + proxied DNS record; tunnel config never changes.
- **Identity**: Authentik is the sole IdP (GitHub org federated upstream) for Argo CD, Grafana, Vault, and the apiserver (JWT `AuthenticationConfiguration` in `talos/all/machine.yaml`). Providers live as blueprints in `kubernetes/authentik/`.
- **Observability**: OTel collectors (`otel-agent` DaemonSet + `otel-gateway` Deployment) are the only collection layer → VictoriaMetrics/VictoriaLogs (VM Operator CRs) → stateless Grafana (dashboards/datasources are CRs). Grafana's "Prometheus" datasource pointing at VM is correct — VM is Prometheus-API-compatible. Scraped infra metrics export via `prometheusremotewrite`, not OTLP, to keep community-dashboard label semantics.

## Gotchas

- **Never commit or push without explicit in-the-moment approval.** Commit messages: brief, single-line, no trailers.
- Both gateways forward **plain HTTP** to backends — apps must not force HTTPS redirects (Argo CD needs `server.insecure: true` under `configs.params`).
- Gateway API is pinned `<1.5` in `renovate.json` — Cilium 1.19 supports v1.4.x only. Don't float it ahead of Cilium.
- Talos `machine.files` with `op: create` only work under `/var` — anywhere else reboot-loops the node, with no apply-time validation.
- `monitoring` namespace is PSA-privileged (via `managedNamespaceMetadata`) — node-exporter needs hostNetwork/hostPID.
- After a node reset, delete the orphan NetBird peer at app.netbird.io, or the apiserver endpoint (`talos-1.netbird.cloud`) drifts to a suffixed name.

## Tooling

- **Docs lookup**: for any third-party API (Talos, Cilium, Helm charts, topf, VictoriaMetrics, Authentik, …) ALWAYS query `get_docs` on the `context` MCP server first; fall back to the web only if it returns nothing.

<!-- rtk-instructions -->
## RTK

Prefix every shell command with `rtk` (`rtk git status`, `rtk kubectl get pods`, `rtk gh pr view`) — a token-filtering proxy that compacts output and passes unknown commands through unchanged, so it is always safe. Applies inside `&&` chains too. `rtk proxy <cmd>` runs unfiltered (debugging); `rtk gain` shows savings.
<!-- /rtk-instructions -->
