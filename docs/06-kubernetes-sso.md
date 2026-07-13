# 06 - Kubernetes API SSO (Authentik OIDC)

Humans authenticate to the kube-apiserver through Authentik OIDC (GitHub-federated
upstream), with RBAC driven by Authentik group membership — the same pattern as
Argo CD and Vault. The cert-based admin kubeconfig stays as **break-glass** and is
never removed (it is part of the Talos PKI).

```
kubectl → kubelogin (browser → Authentik → GitHub) → OIDC token
      → kube-apiserver (validates token against Authentik JWKS)
      → RBAC: group "oidc:authentik Admins" → cluster-admin
```

## What lives in git

| Piece | Where |
| --- | --- |
| Authentik OIDC provider/app `kubernetes` (public + PKCE) | `kubernetes/authentik/blueprint-kubernetes.yaml` (+ listed in `argocd-apps/authentik.yaml`) |
| `ClusterRoleBinding` group→cluster-admin | `kubernetes/rbac/oidc-cluster-admins.yaml` (`argocd-apps/rbac.yaml`) |
| apiserver structured auth config | `talos/all/machine.yaml` (`machine.files` + `cluster.apiServer.extraVolumes`/`extraArgs`) |

Design choices: **public client + PKCE** (no client secret to distribute to
laptops, nothing to store in Vault); username claim **`preferred_username`** and
groups both prefixed **`oidc:`** so an OIDC token can never impersonate a built-in
user or claim `system:masters`.

## Apply order

The GitOps parts (Authentik + RBAC) are risk-free and go first; the apiserver
change is applied last, by hand, via `topf`.

### 1. Ship Authentik provider + RBAC (GitOps)

Push to `main`; Argo CD syncs the `authentik` and `rbac` apps. Confirm the OIDC
app exists and its discovery endpoint is reachable **from the node's network
namespace** (this is what the apiserver will do):

```bash
# discovery endpoint returns 200 once the blueprint is applied
kubectl -n openebs run oidc-probe --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"Default"}}' \
  --command -- curl -sS -o /dev/null -w "%{http_code} tls=%{ssl_verify_result}\n" \
  https://authentik.internal.homelab0.xyz/application/o/kubernetes/.well-known/openid-configuration
# expect: 200 tls=0
```

### 2. Apply the apiserver auth config (Talos)

This rolls the kube-apiserver static pod. OIDC is **additive** — the cert-based
admin auth is untouched, and a recent apiserver does not fail to start if the
issuer is briefly unreachable (JWKS is fetched lazily). Still, do this when you
can watch it and with `talosctl`/PKI kubeconfig handy.

```bash
cd talos
topf render                     # sanity: config resolves + validates
topf apply                      # applies machine config; apiserver static pod rolls

# watch the apiserver recover on the PKI (admin) kubeconfig
KUBECONFIG=~/.kube/homelab.kubeconfig kubectl -n kube-system get pods -l k8s-app=kube-apiserver -w
```

If the apiserver does not come back: revert the `machine.yaml` change and
`topf apply` again. Talos API (`talosctl`, port 50000) is independent of the
kube-apiserver, so you always retain node access to recover.

### 3. Client kubeconfig (kubelogin)

```bash
brew install int128/kubelogin/kubelogin      # provides `kubectl oidc-login`
```

Test the login flow (opens a browser to Authentik):

```bash
kubectl oidc-login setup \
  --oidc-issuer-url=https://authentik.internal.homelab0.xyz/application/o/kubernetes/ \
  --oidc-client-id=kubernetes \
  --oidc-use-pkce \
  --oidc-extra-scope=profile --oidc-extra-scope=email --oidc-extra-scope=groups
```

The output should show your `preferred_username` and a `groups` claim containing
`authentik Admins`. Then wire it into the kubeconfig as a new context reusing the
existing cluster (CA + server) from `~/.kube/homelab.kubeconfig`:

```bash
kubectl config set-credentials oidc \
  --exec-api-version=client.authentication.k8s.io/v1 \
  --exec-command=kubectl \
  --exec-arg=oidc-login,get-token \
  --exec-arg=--oidc-issuer-url=https://authentik.internal.homelab0.xyz/application/o/kubernetes/ \
  --exec-arg=--oidc-client-id=kubernetes \
  --exec-arg=--oidc-use-pkce \
  --exec-arg=--oidc-extra-scope=profile \
  --exec-arg=--oidc-extra-scope=email \
  --exec-arg=--oidc-extra-scope=groups

kubectl config set-context homelab-sso \
  --cluster=<cluster-name-from-homelab.kubeconfig> --user=oidc

kubectl --context homelab-sso get nodes    # first call opens the browser
```

> NetBird must be up: both the apiserver endpoint (`talos-1.netbird.cloud`) and
> Authentik (`authentik.internal.homelab0.xyz`) resolve only over NetBird.

## Verify

```bash
kubectl --context homelab-sso auth whoami          # oidc:<user>, groups oidc:authentik Admins
kubectl --context homelab-sso auth can-i '*' '*'   # yes (cluster-admin via the group)
```

## Break-glass

The Talos-issued admin kubeconfig (`~/.kube/homelab.kubeconfig`, regenerable with
`topf kubeconfig`) is cert-based and bypasses OIDC entirely. Keep it. If Authentik
or the OIDC config ever breaks, use it to get in and fix or revert.
