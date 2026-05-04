# 06 - Talos Cluster

Kubernetes is provisioned via [Talos Linux](https://www.talos.dev/) with Cilium as the CNI and kube-proxy disabled.

## Architecture

| Node | VM ID | IP | vCPU | RAM |
|---|---|---|---|---|
| talos-cp-1 | 110 | 10.50.0.10 | 2 | 8 GB |
| talos-worker-1 | 111 | 10.50.0.11 | 4 | 24 GB |
| talos-worker-2 | 112 | 10.50.0.12 | 4 | 24 GB |

## Bootstrapping Constraints

Talos VMs boot in maintenance mode with no IP and rely on DHCP. The internal bridge `vmbr1` (10.50.0.0/24) has no DHCP server by default, so the Proxmox host runs dnsmasq to provide:

- **DHCP** with fixed leases (MAC → IP) so node IPs match the Talos config
- **NAT (masquerade)** for outbound internet access
- **DNS forwarding** to public resolvers (Hetzner's firewall is stateless and drops UDP responses, so VMs can't reach external DNS directly — Proxmox forwards on their behalf)

Because this dnsmasq setup is one-time manual config on the host, the apply is split into two stages.

## Hetzner Firewall

Hetzner Robot firewall is stateless. Outbound packets are allowed, but responses (TCP ACK, UDP DNS replies, UDP NTP replies) are blocked unless explicitly allowed. Add these rules **before** the final discard rule:

| # | Protocol | Source port | Dest port | Action |
|---|---|---|---|---|
| 1 | ICMP | any | any | accept |
| 2 | TCP | any | any | accept (TCP flag: ACK) |
| 3 | UDP | 53 | any | accept |
| 4 | UDP | 123 | any | accept |
| 5 | UDP | any | 51820 | accept (WireGuard) |

Without these, DNS, NTP, and any TCP return traffic to the Proxmox host (and by extension, NATed VMs) will time out.

## Stage 1 — Proxmox infrastructure

```bash
cd opentofu/infrastructure
tofu apply -target=module.proxmox
```

This creates the bridge, DNS LXC, and Talos VMs.

### Get MAC addresses

```bash
tofu output talos_mac_addresses
```

Output:
```
{
  "talos-cp-1"     = "BC:24:11:xx:xx:xx"
  "talos-worker-1" = "BC:24:11:yy:yy:yy"
  "talos-worker-2" = "BC:24:11:zz:zz:zz"
}
```

### Configure dnsmasq on the Proxmox host

```bash
ssh homelab
apt-get install -y dnsmasq iptables-persistent
```

Write the config (replace MACs with values from the output above):

```bash
cat > /etc/dnsmasq.d/talos.conf << 'EOF'
interface=vmbr1
bind-interfaces

# DHCP
dhcp-range=10.50.0.0,static
dhcp-option=option:router,10.50.0.254
dhcp-option=option:dns-server,10.50.0.254

dhcp-host=BC:24:11:xx:xx:xx,talos-cp-1,10.50.0.10
dhcp-host=BC:24:11:yy:yy:yy,talos-worker-1,10.50.0.11
dhcp-host=BC:24:11:zz:zz:zz,talos-worker-2,10.50.0.12
```

Enable IP forwarding and NAT:

```bash
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-ip-forward.conf
sysctl --system

iptables -t nat -A POSTROUTING -s 10.50.0.0/24 ! -o vmbr1 -j MASQUERADE
iptables -A FORWARD -i vmbr1 -j ACCEPT
iptables -A FORWARD -o vmbr1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Persist rules across reboots
netfilter-persistent save
```

Start dnsmasq:

```bash
systemctl enable --now dnsmasq
```

Verify DNS forwarding works:

```bash
dig @10.50.0.254 google.com
```

If that returns an answer, you're good. If it times out, check the Hetzner firewall rules above.

Reboot the Talos VMs so they pick up DHCP leases:

```bash
qm reboot 110 && qm reboot 111 && qm reboot 112
```

## Stage 2 — Talos cluster

```bash
tofu apply
```

This pushes machine configs to all nodes, bootstraps etcd on the control plane, and retrieves the kubeconfig.

### If the apply gets stuck

If `tofu apply` plans only `bootstrap` + `kubeconfig` (skipping `talos_machine_configuration_apply`) but the VMs are still in maintenance mode, the state is stale. Force a re-push:

```bash
tofu apply \
  -replace='module.talos.talos_machine_configuration_apply.controlplane' \
  -replace='module.talos.talos_machine_configuration_apply.worker["talos-worker-1"]' \
  -replace='module.talos.talos_machine_configuration_apply.worker["talos-worker-2"]'
```

### Reset VMs to maintenance mode

If a node ends up in a bad state, recreate it (fresh disk → falls through to ISO boot → maintenance mode):

```bash
tofu apply \
  -replace='module.proxmox.proxmox_virtual_environment_vm.talos["talos-cp-1"]' \
  -replace='module.proxmox.proxmox_virtual_environment_vm.talos["talos-worker-1"]' \
  -replace='module.proxmox.proxmox_virtual_environment_vm.talos["talos-worker-2"]'
```

Recreated VMs get **new MAC addresses** — re-run `tofu output talos_mac_addresses` and update `/etc/dnsmasq.d/talos.conf`. Clear stale leases and restart:

```bash
systemctl stop dnsmasq
rm /var/lib/misc/dnsmasq.leases
systemctl start dnsmasq
```

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

All three nodes should be `Ready` once Cilium pods are running.
