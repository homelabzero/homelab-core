# 08 - Node Migration (replace the server)

Move the single-node cluster to a new dedicated server without losing data.
Done 2026-09-11 (`talos-1` @ 148.251.156.11 → `talos-2` @ 136.243.147.253).

The cluster config is a function of git, so only **node identity** and
**hostpath data** need to move. Build the new cluster next to the old one,
restore data into it, flip the NetBird route, shut the old node down.
Rollback until the flip is "do nothing"; after it, flip the route back.

## What is stateful

Everything on `openebs-hostpath` is node-local and cannot follow a pod:

| Data | Loss impact | Migration |
| --- | --- | --- |
| Vault raft | every secret, incl. Authentik's `secret_key` | `raft snapshot save` → `restore -force` |
| Authentik Postgres (CNPG) | users, groups, akadmin, setup-disabled flag | `pg_dump -Fc` → `pg_restore` |
| VictoriaMetrics / VictoriaLogs | history only | dropped |
| everything else | none — rebuilt from git | — |

## 1. Prepare the new server

From the Hetzner rescue system record the NIC MAC and the serial of the disk
you will `dd` to (see `02-dedicated-server.md`), then write the image and
reboot into maintenance mode.

## 2. Repoint `talos/` at the new node

- `topf.yaml`: replace the node entry (`host`, public `ip`, `data.mac`,
  `data.systemDiskSerial`), set `clusterEndpoint` to the new peer name.
  **Remove the old node** so `topf apply` can never target it.
- `all/machine.yaml`: `cluster.discovery.enabled: false` (see trap 1).
- `topf render && talosctl validate -c output/<host>.yaml -m metal`.

Reusing `secrets.sops.yaml` is intentional: the new cluster has the same CA,
so the existing talosconfig/kubeconfig work, and the Vault Kubernetes auth
config restored from the snapshot is still valid.

## 3. Bootstrap

```bash
topf apply --auto-bootstrap        # interactive y/n prompt; must say "etcd bootstrap completed"
topf kubeconfig > ~/.kube/homelab-new.kubeconfig
topf talosconfig | sed 's/<public-ip>/<host>.netbird.cloud/g' > ~/.talos/config-new
```

Check app.netbird.io → Peers: the node must appear under its plain hostname
(no `-NNN-NNN` suffix). Then `04-cilium.md` (pin `--version` to the Argo app's
`targetRevision`) and `05-bootstrap.md` steps 1–2. Argo climbs to wave 2 and
stalls on the sealed Vault. **Do not** run step 3 (init/seed) — restore instead.

## 4. Restore data (old cluster still live)

```bash
# --- take from old ---
kubectl --kubeconfig ~/.kube/homelab.kubeconfig -n authentik exec authentik-db-1 -c postgres \
  -- pg_dump -Fc -d authentik > /tmp/authentik.dump
VAULT_ADDR=https://vault.internal.homelab0.xyz vault login       # root token
VAULT_ADDR=https://vault.internal.homelab0.xyz vault operator raft snapshot save /tmp/vault.snap

# --- Authentik DB first: CNPG is up but Authentik pods are blocked on Vault
#     secrets (CreateContainerConfigError), so the DB is empty and untouched ---
kubectl --kubeconfig ~/.kube/homelab-new.kubeconfig -n authentik exec -i authentik-db-1 -c postgres \
  -- pg_restore -d authentik --no-owner --role=authentik --exit-on-error < /tmp/authentik.dump

# --- Vault: throwaway init, unseal, restore, then unseal with the OLD key ---
kubectl --kubeconfig ~/.kube/homelab-new.kubeconfig -n vault port-forward svc/vault 8201:8200 &
export VAULT_ADDR=http://127.0.0.1:8201
vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/vault-tmp.json
vault operator unseal -format=json "$(jq -r .unseal_keys_b64[0] /tmp/vault-tmp.json)"
VAULT_TOKEN=$(jq -r .root_token /tmp/vault-tmp.json) vault operator raft snapshot restore -force /tmp/vault.snap
vault operator unseal                                              # OLD unseal key
```

The restore seals Vault under the snapshot's master key; the temporary
init keys are dead afterwards. Within a minute every `VaultStaticSecret`
goes `Synced`, Authentik starts against the restored schema (same chart
version → no-op migrations), and waves 3–5 turn Healthy.

Verify from inside the cluster (Cilium gateway Services have no selector, so
`port-forward` cannot attach):

```bash
kubectl run smoke --rm -i --restart=Never --image=curlimages/curl -- \
  curl -sk -o /dev/null -w '%{http_code}\n' --resolve argocd.internal.homelab0.xyz:443:10.60.0.1 \
  https://argocd.internal.homelab0.xyz/healthz
```

## 5. Cut over

1. app.netbird.io → Networks → `internal-gateway` → routing peer: old → new.
   `netbird status -d` on the laptop shows `Networks: 10.60.0.1/32` under the
   new peer within seconds; the public route needs nothing (both `cloudflared`
   connectors are live on the same tunnel).
2. `talosctl shutdown --nodes <old>.netbird.cloud` — shut down, don't wipe.
   Rollback = Robot hardware reset + route back.
3. Swap laptop creds: `~/.kube/homelab.kubeconfig` ← new, `~/.talos/config` ← new.
4. `topf.yaml`: node `ip` → its NetBird IP (day-2 target).
5. Delete the old peer in NetBird; cancel the old server once you are sure.

## Traps hit on the way

1. **Discovery auto-joins etcd.** With `cluster.discovery.enabled` (default
   on) and a shared PKI, the fresh node found the live node via the discovery
   service and joined its etcd (`etcd already bootstrapped member_count=2`)
   over NetBird — you get a two-node control plane instead of a new cluster,
   with cross-node pod traffic unencrypted between datacenters. Recovery:
   `talosctl etcd leave` on the new node, `kubectl delete node`, reset it.
2. **`talosctl reset --wipe-mode system-disk` wipes the whole disk**, Talos
   install included; the box then boots into nothing and needs a fresh `dd`
   from rescue. To return to maintenance mode use
   `--system-labels-to-wipe STATE,EPHEMERAL` instead.
3. **A reset node re-enrolls in NetBird as a new peer.** Delete the stale
   peer *before* the node comes back, or it gets a suffixed name and the
   cluster endpoint DNS points at the dead peer.
4. **Both Gateways created at once race for `10.60.0.1`.** Fixed by pinning
   `gateway-public` to `10.60.0.2` in git; on the old cluster the order of
   creation had hidden it.
5. **Hostpath PV `nodeAffinity` is the node name.** Renaming the node after
   the fact would orphan every PV; keep the new hostname and update docs
   instead.
6. **Enumeration differs between rescue and Talos** (`nvme0n1` in rescue was
   `nvme1n1` in Talos; `eth0` was `enp35s0`). Hence `install.diskSelector.serial`
   and `deviceSelector.hardwareAddr`, never device names.
