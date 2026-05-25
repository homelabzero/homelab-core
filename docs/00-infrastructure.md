# 00 - Infrastructure

## Cloud Control Planes (Hetzner Cloud)

3x CPX22 — $9.49 / month each ($28.47 total)

| Node       | Region | CPU          | RAM  | Storage    |
| ---------- | ------ | ------------ | ---- | ---------- |
| talos-cp-1 | nbg1   | 2 vCPU (AMD) | 4 GB | 80 GB NVMe |
| talos-cp-2 | fsn1   | 2 vCPU (AMD) | 4 GB | 80 GB NVMe |
| talos-cp-3 | hel1   | 2 vCPU (AMD) | 4 GB | 80 GB NVMe |

## Dedicated Server (Hetzner) — Worker

Region: FSN1 — $52 / month

| Component | Spec                       |
| --------- | -------------------------- |
| CPU       | AMD Ryzen 5 3600           |
| RAM       | 2x 32 GB DDR4 ECC (64 GB)  |
| Storage   | 2x 512 GB SSD M.2 NVMe     |
| NIC       | Intel I210 (1 Gbit)        |

## Object Storage (Hetzner Cloud)

Region: FSN1 — $7.99 / TB / month (per account)

- OpenTofu state bucket

## Domain

| Domain       | Registrar  | Price            |
| ------------ | ---------- | ---------------- |
| homelab0.xyz | Cloudflare | $1.18 / year (discount) |
