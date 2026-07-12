# Features

## Argo CD

- **App-of-apps** pattern — single root Application syncs all apps from `kubernetes/argocd-apps/`
- **Self-managed** — Argo CD manages its own Helm release via the app-of-apps, upgrades are applied by pushing to git
- **Sync waves** enforce deployment order — dependencies are guaranteed to be healthy before dependent apps are reconciled
- **Authentik OIDC SSO** — Argo CD authenticates directly against Authentik via OIDC (no Dex); Authentik federates GitHub org membership upstream. Admin rights are granted by mapping the `authentik Admins` group to `role:admin`
- **Static admin disabled** — only Authentik SSO accounts can log in (break-glass: re-enable `admin.enabled` in git)
- **GitHub webhook** on push to `main` triggers immediate reconciliation — the periodic reconciliation loop is raised to **10 minutes** (from the 3-min default); with the webhook handling immediate syncs, the long loop is just a fallback and cuts reconciliation spam
- **Webhook endpoint** (`/api/webhook`) exposed publicly on `gateway-public` with HMAC-SHA256 secret verification — all other ArgoCD paths remain internal-only

## Networking & access

- **Two access paths, two gateways** — private via **NetBird** (`*.internal.homelab0.xyz` → `gateway-internal`, pinned LB VIP `10.60.0.1`); public via **Cloudflare Tunnel** (`*.homelab0.xyz` → `gateway-public`)
- **Cloudflare Tunnel (cloudflared)** — an **outbound-only** connector (DaemonSet, one per node) publishes selected services to the internet with **no inbound ports** and **without exposing the node's public IP**. Cloudflare terminates TLS at its edge and forwards plain HTTP over the tunnel to the HTTP-only `gateway-public`
- **HTTPRoute is the public gate** — a service is reachable publicly only if it attaches an HTTPRoute to `gateway-public`; adding one + a proxied DNS record is the whole workflow, the tunnel's catch-all config never changes
- **GitOps-native tunnel** — ingress rules live in the `cloudflared` Helm values in git; only the tunnel credentials (`cert.pem`, `credentials.json`) come from Vault via VSO, never git
