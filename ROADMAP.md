# Roadmap

## Planned

- [ ] Migrate to 3 worker nodes for full HA setup
- [ ] RAID 1 on Talos worker nodes — requires Talos v1.14 (https://github.com/siderolabs/talos/discussions/8654)
- [ ] HA Mayastor — add 2 more worker nodes, migrate to 3-replica StorageClass and etcd, bump `mayastor.etcd.replicaCount` to 3
- [ ] HA Vault — migrate from single-replica Raft to 3-replica once 3 workers are available
- [ ] Kyverno — admission-time policy enforcement (resource limits, image registry allowlist, no-root containers, namespace standards)
- [ ] Tetragon — eBPF runtime security enforcement (syscall monitoring, reverse shell detection, process kill policies)
- [ ] Cilium Network Policies — default-deny posture with explicit allowlists per service; L7 policies for HTTP/DNS-aware rules; Hubble shows dropped packets with policy reason
- [ ] Public website (homelab0.xyz) — document the project architecture, design decisions, and best practices
