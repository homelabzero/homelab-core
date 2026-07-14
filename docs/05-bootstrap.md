# 05 - GitOps Bootstrap

Once Talos is up and Cilium is installed (see `04-cilium.md`), everything else
is GitOps via Argo CD. But GitOps can't install its own engine, and Vault can't unseal itself — so three things are bootstrapped by hand. After that, Argo CD owns the whole stack from Git.

## The bootstrap chain

```
Cilium  →  Argo CD  →  Vault (unseal + seed)
 (CNI)     (engine)     (secret root of trust)
                              ↓
            Argo CD walks the sync-waves; every app self-heals from Git
```

| Manual (once) | Then GitOps owns it |
| ------------- | ------------------- |
| Cilium install | `cilium` app adopts the release |
| Argo CD install + apply `root` | `argocd` app self-manages |
| Vault **unseal + seed** | `vault` app already owns the release; VSO syncs secrets out |

> **Why Vault is *installed* by GitOps, not by hand.** Vault's raft storage uses
> the `openebs-single-replica` StorageClass, which is itself an Argo CD app
> (OpenEBS, an early wave). Installing Vault manually would drag OpenEBS into the
> manual path too. So Argo CD installs Vault like any other app — a sealed Vault
> pod just reports **not Ready**, which stalls its sync-wave (wave 2) and stops
> Argo CD from ever reaching the secret-consuming waves (cert-manager at 3;
> external-dns / authentik / gateway at 4; argocd at 5). That stall *is* the gate:
> nothing that needs a secret is created until you unseal. Your only manual Vault
> job is `init` / unseal / seed.
>
> VSO itself is installed *before* Vault (wave 1) so its `VaultStaticSecret` CRD
> exists for every consumer app. Every `VaultStaticSecret` lives in an app that
> syncs at or after the Vault gate, so by the time it is applied Vault is already
> unsealed and seeded and the secret populates immediately.

## Prerequisites

- Talos cluster reachable (`kubectl get nodes` → `Ready`, via NetBird).
- Cilium installed and nodes `Ready` (`04-cilium.md`).
- `helm`, `kubectl`, and the `vault` CLI on the laptop.

## 1. Install Argo CD (manual, one-time)

This is disposable scaffolding — install it bare. Only `dex` and
`notifications` are disabled here; everything else the `argocd` app declares
(`global.domain`, `server.insecure`, OIDC, RBAC) is reconciled the moment that
app adopts the release. Keep `--version` matched to the app's `targetRevision`
so adoption is a clean values-only reconcile, not a chart up/downgrade.

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --version 9.5.15 \
  --namespace argocd --create-namespace \
  --set dex.enabled=false \
  --set notifications.enabled=false

# initial admin password (until Authentik SSO is wired + admin disabled)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

> Without `server.insecure`, argocd-server keeps its own TLS until the `argocd`
> app flips it — reach the bootstrap UI over `https://localhost:8080` with
> `kubectl -n argocd port-forward svc/argocd-server 8080:443` (accept the
> self-signed cert). A short pod restart when the app reconciles `insecure=true` is expected.

## 2. Apply the app-of-apps root

```bash
kubectl apply -f kubernetes/app-of-apps.yaml
```

`root` points at `kubernetes/argocd-apps` and creates every Application in
sync-wave order. Watch it climb:

```bash
kubectl -n argocd get applications -w
```

It will progress through the secret-free foundation in wave order — Cilium adopt
(0), VSO + OpenEBS (1) — and then **stall** at wave 2: the `vault` app stays
`Progressing` because the pod is sealed. That is expected; the later waves
(cert-manager at 3; external-dns / authentik / gateway at 4; argocd at 5) wait
behind it. Unseal it next.

## 3. Initialize, unseal and seed Vault (manual, one-time)

Talk to Vault directly over a port-forward (the ingress path can't be used yet — it depends on a Cloudflare token that lives *inside* Vault).

```bash
kubectl -n vault port-forward svc/vault 8200:8200 &
export VAULT_ADDR=http://127.0.0.1:8200
```

### Init + unseal

```bash
# Homelab: 1 share / 1 threshold. Use 5/3 for anything real.
vault operator init -key-shares=1 -key-threshold=1
# → records an Unseal Key and an Initial Root Token. SAVE BOTH SECURELY.

vault operator unseal <UNSEAL_KEY>
vault login <ROOT_TOKEN>
```

> Save the unseal key and root token in your password manager. After any node
> reboot Vault comes back **sealed** and you must `vault operator unseal` again,
> until you set up auto-unseal (see Notes).

### Enable the KV store

```bash
vault secrets enable -path=secret -version=2 kv
```

### Enable Kubernetes auth for Vault Secrets Operator

The VSO app (`defaultAuthMethod` in `vso.yaml`) authenticates with the
`vault-auth` service account, audience `vault`. VSO resolves that ServiceAccount
in the **consuming secret's own namespace** (not the operator's), so every
namespace that holds a `VaultStaticSecret` ships its own `vault-auth` SA
(`kubernetes/<app>/vault-auth.yaml`). The role below therefore binds the
`vault-auth` name across **all** namespaces — each new consumer just adds a
`vault-auth` SA, no Vault change needed.

```bash
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host=https://kubernetes.default.svc

vault policy write vso - <<'EOF'
path "secret/data/*"     { capabilities = ["read"] }
path "secret/metadata/*" { capabilities = ["read", "list"] }
EOF

vault write auth/kubernetes/role/vault-secrets-operator \
  bound_service_account_names=vault-auth \
  bound_service_account_namespaces='*' \
  audience=vault \
  policies=vso \
  ttl=1h
```

### Seed the secret data

These are the values the downstream apps consume through VSO. The KV paths and
key names below must match the VaultStaticSecret manifests exactly (mount
`secret`, kv-v2) — VSO copies every key in the Vault secret into the destination
Kubernetes Secret verbatim.

```bash
# Cloudflare API token — cert-manager DNS-01 issuer + external-dns
vault kv put secret/core/cloudflare-api-token api-token=<CF_TOKEN>

# Authentik server secret key
vault kv put secret/core/authentik-secret-key secret-key="$(openssl rand -base64 60)"

# GitHub OAuth app — backs the Authentik GitHub source (org login).
# Create an OAuth app at github.com/settings/developers with callback
# https://authentik.internal.homelab0.xyz/source/oauth/callback/github/
vault kv put secret/core/authentik-github-oauth \
  client-id=<GITHUB_CLIENT_ID> \
  client-secret=<GITHUB_CLIENT_SECRET>

# Argo CD OIDC client secret — value comes from Authentik (step 5), seed empty now
vault kv put secret/core/argocd-oidc clientSecret=""

# Argo CD GitHub webhook HMAC secret — verifies the public /api/webhook endpoint.
# Set the SAME value as the secret on the GitHub webhook (repo/org → Webhooks).
vault kv put secret/core/argocd-webhook webhook-secret="$(openssl rand -hex 32)"

# Vault's own OIDC client secret (Vault is the OIDC client, Authentik the IdP).
# Generate it here and reuse the SAME value in auth/oidc/config (step 7).
vault kv put secret/core/vault-oidc clientSecret="$(openssl rand -base64 48)"

# Grafana OIDC client secret — consumed by both Authentik (provider side) and
# Grafana (client side) via VSO, so a single generated value wires both.
vault kv put secret/core/grafana-oidc clientSecret="$(openssl rand -base64 48)"

# Cloudflare Tunnel — the origin cert + tunnel credentials produced by
# `cloudflared tunnel create` (see step 9). Keys MUST be cert.pem /
# credentials.json (VSO copies key names verbatim). Safe to seed later: the
# cloudflared app just stays Progressing until these exist, like any other.
vault kv put secret/core/cloudflared-cert        cert.pem=@$HOME/.cloudflared/cert.pem
vault kv put secret/core/cloudflared-credentials credentials.json=@$HOME/.cloudflared/<TUNNEL_UUID>.json
```

> **Note — paths/keys must match the VaultStaticSecret manifests.** VSO reads
> these Vault paths and materializes them as Kubernetes Secrets. Every VSS is
> colocated with the app that consumes it, so its namespace already exists and
> the VSS CRD (installed by VSO at wave 1) is present when the object is applied:
>
> | Vault path (`mount: secret`) | keys | → K8s Secret (namespace) | manifest |
> | --- | --- | --- | --- |
> | `core/cloudflare-api-token` | `api-token` | `cloudflare-api-token` (`cert-manager`, `external-dns`) | `kubernetes/cloudflare/vault-static-secret.yaml` (one namespace-less VSS, added as an extra source on both the `cert-manager` and `external-dns` apps so each projects it into its own namespace) |
> | `core/authentik-secret-key` | `secret-key` | `authentik-secret-key` (`authentik`) | `kubernetes/authentik/secret-key.yaml` |
> | `core/authentik-github-oauth` | `client-id`, `client-secret` | `authentik-github-oauth` (`authentik`) | `kubernetes/authentik/github-oauth.yaml` |
> | `core/argocd-oidc` | `clientSecret` | `argocd-oidc` (`argocd`) | `kubernetes/argocd/argocd-oidc.yaml` |
> | `core/argocd-webhook` | `webhook-secret` | `argocd-webhook` (`argocd`) | `kubernetes/argocd/argocd-webhook.yaml` (labeled `part-of: argocd`; argocd-cm reads it as `$argocd-webhook:webhook-secret`) |
> | `core/vault-oidc` | `clientSecret` | `vault-oidc` (`authentik`) | `kubernetes/authentik/vault-oidc.yaml` (consumed by Authentik as `VAULT_OIDC_CLIENT_SECRET`; the same value is set in Vault's `auth/oidc/config`) |
> | `core/grafana-oidc` | `clientSecret` | `grafana-oidc` (`authentik`, `monitoring`) | `kubernetes/authentik/grafana-oidc.yaml` + `kubernetes/grafana/grafana-oidc.yaml` (Authentik reads it as `GRAFANA_OIDC_CLIENT_SECRET`; Grafana as `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET`) |
> | `core/cloudflared-cert` | `cert.pem` | `cloudflared-cert` (`cloudflared`) | `kubernetes/cloudflared/cert.yaml` |
> | `core/cloudflared-credentials` | `credentials.json` | `cloudflared-credentials` (`cloudflared`) | `kubernetes/cloudflared/credentials.yaml` |

## 4. Let GitOps finish

With Vault unsealed and Ready, Argo CD resumes past the gate: VSO comes up,
writes the Kubernetes Secrets, and the gateway / cert-manager issuer /
external-dns / Authentik apps go Healthy on their own.

```bash
kubectl -n argocd get applications
# everything Synced + Healthy
```

## 5. Wire Argo CD ↔ Authentik SSO (after Authentik is up)

The Argo CD ⟷ Authentik OIDC dependency is a soft cycle — Argo CD runs fine on
the local admin login meanwhile.

1. In Authentik, create an OAuth2/OIDC provider + application for Argo CD
   (`https://argocd.internal.homelab0.xyz/application/o/argocd/`).
2. Put the generated client secret into Vault:
   ```bash
   vault kv patch secret/core/argocd-oidc clientSecret=<CLIENT_SECRET>
   ```
3. VSO refreshes `argocd-oidc`; Argo CD picks up `$argocd-oidc:clientSecret` and
   the Authentik login button appears. Local admin remains as a break-glass path.

## 6. Disable the local admin (final hardening, GitOps)

Only after you have logged in via Authentik SSO **and confirmed admin rights**
(the `g, authentik Admins, role:admin` mapping works) — otherwise you lock
yourself out with no admin and no working SSO. Add to `configs.cm` in
`kubernetes/argocd-apps/argocd.yaml`:

```yaml
        configs:
          cm:
            admin.enabled: "false"
```

Commit; the `argocd` app reconciles it and the local admin login is gone.

> **Break-glass.** If SSO ever breaks while admin is disabled, revert that line
> in Git — the application-controller re-enables admin on its own (it syncs
> without a logged-in user). Or patch live: `kubectl -n argocd patch cm
> argocd-cm --type merge -p '{"data":{"admin.enabled":"true"}}'`.

## 7. Wire Vault ↔ Authentik SSO (after Authentik is up)

Authentik already ships the Vault OIDC provider/application as GitOps
(`kubernetes/authentik/blueprint-vault.yaml`, slug `vault`, issuer
`https://authentik.internal.homelab0.xyz/application/o/vault/`). Its client
secret is the `core/vault-oidc` value seeded in step 3 — Authentik reads it as
`VAULT_OIDC_CLIENT_SECRET`, and you set the *same* value on Vault below. The
Vault auth method itself is configured by hand (like the Kubernetes auth method
above — Vault config is not GitOps).

```bash
# Reuse the value seeded into Vault in step 3, so client + IdP agree.
CS=$(vault kv get -field=clientSecret secret/core/vault-oidc)

vault auth enable oidc
vault write auth/oidc/config \
  oidc_discovery_url="https://authentik.internal.homelab0.xyz/application/o/vault/" \
  oidc_client_id="vault" \
  oidc_client_secret="$CS" \
  default_role="default"

# Full-access policy (OSS has no built-in "admin" policy).
vault policy write admin - <<'EOF'
path "*" { capabilities = ["create","read","update","delete","list","sudo","patch"] }
EOF

# OIDC login role. groups_claim lets Vault map Authentik groups -> policies.
vault write auth/oidc/role/default \
  user_claim="sub" \
  oidc_scopes="openid,profile,email,groups" \
  groups_claim="groups" \
  allowed_redirect_uris="https://vault.internal.homelab0.xyz/ui/vault/auth/oidc/oidc/callback,http://localhost:8250/oidc/callback" \
  token_policies="default" \
  token_ttl="1h"

# Bind the Authentik "authentik Admins" group (every GitHub-org member, via the
# existing source mapping) to the admin policy through an external identity group.
vault write identity/group name="authentik Admins" type="external" policies="admin"
GROUP_ID=$(vault read -field=id identity/group/name/"authentik Admins")
ACCESSOR=$(vault auth list -format=json | jq -r '."oidc/".accessor')
vault write identity/group-alias name="authentik Admins" \
  mount_accessor="$ACCESSOR" canonical_id="$GROUP_ID"
```

Log in to confirm before hardening:

```bash
# CLI (opens a browser to Authentik):
vault login -method=oidc role=default
# UI: https://vault.internal.homelab0.xyz → method "OIDC" (or append
#     ?with=oidc%2F to the login URL).
```

## 8. Make Authentik the only human login (final hardening)

Only after an OIDC login lands you with the `admin` policy. Two structural
caveats: the **`token`** auth method is built in and can never be disabled (it
backs every issued token, including the ones OIDC mints), and the
**`kubernetes`** auth method **must stay** — VSO uses it to materialize every
Secret in the cluster; disabling it breaks cert-manager, external-dns,
Authentik, Argo CD and more. No other interactive method (userpass/ldap/github)
is enabled, so the only remaining human path is the initial **root token** —
revoke it:

```bash
vault auth list          # sanity: expect only kubernetes/, oidc/, token/
vault token revoke <ROOT_TOKEN>
```

OIDC via Authentik is now the only way a human logs in.

> **Break-glass.** With the root token gone, regenerate one from the unseal key:
> `vault operator generate-root -init`, then `vault operator generate-root` with
> your unseal key (and the OTP) to recover a one-time root token. Keep the unseal
> key safe — it is the only recovery path.

## 9. Public access via Cloudflare Tunnel (cloudflared)

NetBird is the private path (`*.internal.homelab0.xyz` → `gateway-internal`).
For anything that must be reachable from the public internet, the `cloudflared`
app runs an **outbound-only** Cloudflare Tunnel — no inbound ports open on the
node, the public IP is never advertised. Cloudflare terminates TLS at its edge
and forwards plain HTTP over the tunnel to the HTTP-only `gateway-public`; the
Gateway + its HTTPRoutes do host/path routing and are the actual public gate.

**Make a service public** = attach an HTTPRoute with `parentRef: gateway-public`
(mirrors the internal gateway) **and** add a proxied DNS record for its hostname.
Nothing in the cloudflared config changes. First route shipped: Argo CD's
`/api/webhook` on `argocd.homelab0.xyz` (all other Argo CD paths stay internal).

The tunnel identity is created once, by hand (like the Vault auth methods):

```bash
brew install cloudflared

# Browser auth for the homelab0.xyz zone → writes ~/.cloudflared/cert.pem
cloudflared tunnel login

# Create the tunnel → writes ~/.cloudflared/<TUNNEL_UUID>.json (credentials)
cloudflared tunnel create homelab

# Put the printed UUID into kubernetes/argocd-apps/cloudflared.yaml
#   tunnelConfig.name: "<TUNNEL_UUID>"     (the UUID is not a secret)
# and seed cert.pem + credentials.json into Vault (step 3's last two commands).

# Point each public hostname at the tunnel (proxied CNAME -> <UUID>.cfargotunnel.com).
# CLI (uses cert.pem), or do it by hand in the Cloudflare dashboard:
cloudflared tunnel route dns homelab argocd.homelab0.xyz
```

Once the UUID is committed and Vault holds the two secrets, VSO materializes
`cloudflared-cert` / `cloudflared-credentials`, the DaemonSet goes Ready, and
the tunnel's four edge connections come up. Verify:

```bash
kubectl -n cloudflared logs -l app=cloudflared --tail=20   # "Registered tunnel connection" x4
curl -I https://argocd.homelab0.xyz/api/webhook            # reaches Argo CD (405/400 = wired, not 5xx)
```

> **Origin cert scope.** `cert.pem` is the account-level Cloudflare cert; the
> pod only needs `credentials.json` at runtime but the chart mounts both. Keep
> `cert.pem` in Vault (never Git). Scope the API token used for `login` to the
> `homelab0.xyz` zone.

## Notes

- **Auto-unseal.** To avoid re-unsealing after every reboot, configure a
  `seal "transit"` or cloud-KMS auto-unseal in the Vault Helm values. Worth doing
  once you scale to 3 nodes; optional on a single node.
- **HA.** When scaling out, set `redis-ha.enabled: true` in the `argocd` app,
  raise Vault to a raft quorum (3 pods), and bump the CNPG / Valkey replicas. The
  bootstrap sequence above is unchanged.
