# Features

## Argo CD

- **App-of-apps** pattern — single root Application syncs all apps from `kubernetes/argocd-apps/`
- **Self-managed** — Argo CD manages its own Helm release via the app-of-apps, upgrades are applied by pushing to git
- **Sync waves** enforce deployment order — dependencies are guaranteed to be healthy before dependent apps are reconciled
- **Authentik OIDC SSO** — Argo CD authenticates directly against Authentik via OIDC (no Dex); Authentik federates GitHub org membership upstream. Admin rights are granted by mapping the `authentik Admins` group to `role:admin`
- **Static admin disabled** — only Authentik SSO accounts can log in (break-glass: re-enable `admin.enabled` in git)
- **GitHub webhook** on push to `main` triggers immediate reconciliation — the periodic reconciliation loop is raised to **10 minutes** (from the 3-min default); with the webhook handling immediate syncs, the long loop is just a fallback and cuts reconciliation spam
- **Webhook endpoint** (`/api/webhook`) exposed publicly on `gateway-public` with HMAC-SHA256 secret verification — all other ArgoCD paths remain internal-only
