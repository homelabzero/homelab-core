# Features

## Argo CD

- **App-of-apps** pattern — single root Application syncs all apps from `kubernetes/argocd-apps/`
- **Self-managed** — Argo CD manages its own Helm release via the app-of-apps, upgrades are applied by pushing to git
- **Sync waves** enforce deployment order — dependencies are guaranteed to be healthy before dependent apps are reconciled
- **GitHub OAuth SSO** via Dex — login with GitHub account, no username/password form
- **Static admin disabled** — only GitHub SSO accounts can log in
- **GitHub webhook** on push to `main` triggers immediate reconciliation — Argo CD reconciliation loop (3 min) acts as fallback if webhook is missed
- **Webhook endpoint** (`/api/webhook`) exposed publicly on `gateway-public` with HMAC-SHA256 secret verification — all other ArgoCD paths remain internal-only
