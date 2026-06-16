# 00 - Infrastructure

## Dedicated Server (Hetzner Robot)

One AX41-NVMe in FSN1 — combined control plane + worker. The cluster scales to
3 nodes by adding entries to `nodes` in `talos/topf.yaml`.

| Component | Spec                       |
| --------- | -------------------------- |
| CPU       | AMD Ryzen 5 3600           |
| RAM       | 2x 32 GB DDR4 ECC (64 GB)  |
| Storage   | 2x 512 GB SSD M.2 NVMe     |
| NIC       | Intel I210 (1 Gbit)        |

## NetBird Cloud

Free tier — laptop ↔ node WireGuard mesh + private DNS (`*.netbird.cloud`).
Used as the only laptop access path to the cluster. No host-level WireGuard.

## Domain

| Domain       | Registrar  | Price                   |
| ------------ | ---------- | ----------------------- |
| homelab0.xyz | Cloudflare | $1.18 / year (discount) |

Used by cert-manager (DNS-01) and external-dns. Not used for the kube-apiserver endpoint — that goes through NetBird.
