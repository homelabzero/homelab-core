# 04 - Cilium

Cilium is the CNI and replaces kube-proxy. Nodes stay `NotReady` until it is installed.

## Install

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
  --set k8sServicePort=7445 \
  --set gatewayAPI.enabled=true \
  --set gatewayAPI.enableAlpn=true \
  --set gatewayAPI.enableAppProtocol=true \
  --set operator.replicas=1
```

> `operator.replicas=1` because the operator has node anti-affinity; on a
> single node the second replica stays `Pending`. Drop the flag (defaults
> to 2) when scaling to 3 nodes.

## Verify

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl get nodes
```

All nodes should be `Ready`.
