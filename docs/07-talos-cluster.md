# 07 - Talos Cluster

Kubernetes is provisioned via [Talos Linux](https://www.talos.dev/) with Cilium as the CNI and kube-proxy disabled.

## Architecture

| Node | VM ID | vCPU | RAM |
|---|---|---|---|
| talos-cp-1 | 110 | 2 | 8 GB |
| talos-worker-1 | 111 | 4 | 24 GB |
| talos-worker-2 | 112 | 4 | 24 GB |

The internal subnet `10.50.0.0/24` is provisioned as a Proxmox SDN simple zone (`homelab`) with a vnet (`internal`). DHCP, NAT, and IPAM are managed by Proxmox SDN — there is no manual host-side network configuration.

Node IPs are assigned by Proxmox IPAM (dnsmasq) and are sticky per MAC address. They are not hardcoded — OpenTofu reads them dynamically from the QEMU guest agent.

## How bootstrapping works

Talos VMs boot in maintenance mode and get IPs via DHCP. Three pieces make the bootstrap automatic:

1. **Custom Talos ISO from [factory.talos.dev](https://factory.talos.dev)** — generated at apply time via the Image Factory schematic API with the `qemu-guest-agent` system extension baked in.
2. **Factory installer image** — the same schematic ID is wired into `machine.install.image` so when Talos installs itself to disk it uses the factory installer (not the upstream `siderolabs/installer`). Without this, the QEMU agent disappears after the post-install reboot.
3. **QEMU guest agent** — reports the DHCP-assigned IP back to Proxmox, exposed in OpenTofu as `vm.ipv4_addresses`.

OpenTofu reads each VM's DHCP IP, pushes the Talos machine config to it (nameservers, CNI config, install disk + image), then bootstraps etcd and retrieves the kubeconfig — all against the same DHCP IP. No static IP management needed.

## Apply

This step assumes [PowerDNS](06-powerdns.md) is already configured and answering on `10.50.0.1`. The Talos machine config sets `nameservers = ["10.50.0.1"]`, so DNS must work before bootstrap.

```bash
cd opentofu/infrastructure
tofu apply
```

OpenTofu reads each VM's DHCP IP from the QEMU agent, pushes the Talos machine config (resolvers, CNI=none, install disk + factory installer image), bootstraps etcd, and writes out the kubeconfig.

## Access the Cluster

```bash
mkdir -p ~/.kube ~/.talos
tofu output -raw kubeconfig  > ~/.kube/homelab.kubeconfig
tofu output -raw talosconfig > ~/.talos/config

export KUBECONFIG=~/.kube/homelab.kubeconfig
kubectl get nodes
```

Nodes will show `NotReady` until Cilium is installed.

## Install Cilium

Cilium replaces kube-proxy (disabled in Talos config). Install via Helm:

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445
```

Verify:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl get nodes
```

## Troubleshooting

### Apply hangs on VM creation

OpenTofu blocks waiting for the QEMU agent. If a VM never gets an IP:

- Confirm SDN is applied: `pvesh get /cluster/sdn/zones/homelab` should show `state: available`
- Check dnsmasq is running: `systemctl status dnsmasq@homelab`
- Check the VM console — Talos prints its DHCP IP, or errors if DHCP fails

### Plan/apply hangs on state refresh

The Proxmox provider reads the QEMU agent during refresh. If a VM is rebooting this blocks for up to 15 minutes. Stop VMs first:

```bash
qm stop 110 && qm stop 111 && qm stop 112
tofu destroy -target=module.talos \
  -target='module.proxmox.proxmox_virtual_environment_vm.talos["talos-cp-1"]' \
  -target='module.proxmox.proxmox_virtual_environment_vm.talos["talos-worker-1"]' \
  -target='module.proxmox.proxmox_virtual_environment_vm.talos["talos-worker-2"]'
tofu apply
```

### MacBook can't reach VMs (network unreachable)

Check `ip route get 10.50.0.x` on the Proxmox host. If it shows `dev vmbr1` instead of `dev internal`, a stale bridge is stealing the route:

```bash
ip addr del 10.50.0.254/24 dev vmbr1
```

### Reset a node to maintenance mode

```bash
tofu apply -replace='module.proxmox.proxmox_virtual_environment_vm.talos["talos-cp-1"]'
```

The recreated VM gets a new DHCP lease automatically via the agent.

### Force re-push the Talos config

```bash
tofu apply \
  -replace='module.talos.talos_machine_configuration_apply.controlplane' \
  -replace='module.talos.talos_machine_configuration_apply.worker["talos-worker-1"]' \
  -replace='module.talos.talos_machine_configuration_apply.worker["talos-worker-2"]'
```
