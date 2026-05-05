# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal homelab infrastructure built on **Proxmox** (hosted on Hetzner Cloud), accessed via **WireGuard VPN**, with **Kubernetes** running via Talos Linux + Cilium CNI. Infrastructure-as-Code uses **OpenTofu**.

## Required Tools (macOS)

```bash
brew install talosctl kubectl helm cilium-cli opentofu
```

## Network Architecture

- **Hypervisor**: Proxmox on Hetzner Cloud server
- **VPN**: WireGuard on UDP 51820; VPN subnet `10.25.0.0/24`
  - Server: `10.25.0.1` (Proxmox host)
  - Client: `10.25.0.2` (MacBook)
- **SSH access**: `ssh homelab` (via WireGuard tunnel, see `~/.ssh/config`)
- **Internal VM network**: `10.50.0.0/24` on Proxmox SDN simple zone `homelab` / vnet `internal`; SDN provides DHCP (auto-managed dnsmasq) and SNAT. Gateway `10.50.0.254`
- **Hetzner firewall**: Stateless — blocks return traffic by default; rules added for TCP ACK, UDP src 53, UDP src 123, UDP dst 51820

## Repository Structure

```
opentofu/
  infrastructure/   # OpenTofu root module (environment-specific)
  modules/          # Reusable OpenTofu modules (proxmox, talos)
ansible/
  playbooks/        # powerdns.yml, step-ca.yml
  roles/            # powerdns, step-ca
  inventories/      # homelab.ini
kubernetes/         # ArgoCD app-of-apps manifests
docs/               # Documentation (numbered 00–08)
```

## Deployment Layers

Each layer assumes the previous one is up. Re-running any layer is safe.

1. **OpenTofu** (`opentofu/infrastructure/`) — Proxmox SDN, DNS LXC, Talos VMs (custom ISO from [factory.talos.dev](https://factory.talos.dev) with QEMU agent extension); reads DHCP IPs via the agent, pushes Talos machine configs, bootstraps etcd, writes kubeconfig. See `docs/05-opentofu-proxmox.md` and `docs/07-talos-cluster.md`.
2. **Ansible** (`ansible/`) — runs against the DNS LXC via WireGuard + ProxyJump. Provisions PowerDNS and step-ca (`docs/06-dns-and-ca.md`). Both are foundational infrastructure that must survive cluster rebuilds, hence on the LXC rather than in-cluster.
3. **Cluster bootstrap** — Cilium via Helm (kube-proxy is disabled in Talos config), then ArgoCD via Helm with `kubernetes/app-of-apps.yaml` taking over the rest.

State files, tfvars, `.terraform/` are gitignored — never commit these. Secrets (PowerDNS API key, step-ca passwords) are passed via env vars (`PDNS_API_KEY`, `STEP_CA_PASSWORD`, `STEP_CA_PROVISIONER_PASSWORD`) — no vaults, no committed secrets.

## Security Notes

- SSH password auth is disabled on Proxmox; key-only
- WireGuard private/public keys and `wg*.conf` files are gitignored — never commit them
- Kubeconfig and all credential files (`.pem`, `.key`, `.crt`, `.env`) are gitignored

<!-- rtk-instructions v2 -->
# RTK (Rust Token Killer) - Token-Optimized Commands

## Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## RTK Commands by Workflow

### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

### Test (60-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk go test             # Go test failures only (90%)
rtk jest                # Jest failures only (99.5%)
rtk vitest              # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk pytest              # Python test failures only (90%)
rtk rake test           # Ruby test failures only (90%)
rtk rspec               # RSpec test failures only (60%)
rtk test <cmd>          # Generic test wrapper - failures only
```

### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
```

### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%)
rtk find <pattern>      # Find grouped by directory (70%)
```

### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

## Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->
