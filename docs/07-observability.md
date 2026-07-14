# 07 - Observability (VictoriaMetrics + OpenTelemetry + Grafana)

All-Victoria observability platform with OpenTelemetry as the single collection
layer and Grafana as the single UI. Phase 1 covers **metrics**; logs
(VictoriaLogs) and traces (VictoriaTraces) are later phases that reuse the same
collectors and backends pattern.

```
node-exporter, kubelet, cAdvisor ──scrape── otel-agent   (DaemonSet, node-local)
kube-state-metrics, annotated pods ─scrape─ otel-gateway (Deployment)
your apps (later) ──────────────────OTLP──► otel-gateway
                                                │ otlphttp
                                                ▼
                       VMSingle  (:8428 /opentelemetry/v1/metrics)
                                                ▼
                  Grafana ── gateway-internal ── NetBird ── you
```

## Components (all Argo CD apps, namespace `monitoring`)

| App | Wave | What it deploys |
| --- | --- | --- |
| `victoria-metrics` | 4 | VM Operator (Helm) + `VMSingle` CR — 30d retention, 20Gi on `openebs-hostpath` |
| `metrics-sources` | 4 | kube-state-metrics + node-exporter (Prometheus-format sources) |
| `opentelemetry` | 5 | OTel Operator (Helm, needs cert-manager) + two `OpenTelemetryCollector` CRs |
| `grafana` | 5 | Grafana Operator (Helm, **OCI** chart) + `Grafana`/`GrafanaDatasource`/`GrafanaDashboard` CRs |

Design decisions:

- **One collection layer: OpenTelemetry.** No vmagent, no Fluent Bit. Infra
  metrics are scraped with the collector's `prometheus` receiver, so metric
  names/labels stay Prometheus-native and community dashboards work unmodified.
  Everything is exported to VictoriaMetrics' native OTLP endpoint
  (`/opentelemetry/v1/metrics`).
- **Agent/gateway split.** `otel-agent` (DaemonSet) scrapes node-local targets
  (kubelet, cAdvisor, node-exporter) — scales with nodes automatically.
  `otel-gateway` (Deployment) scrapes cluster-level targets (kube-state-metrics,
  pods annotated `prometheus.io/scrape: "true"`) and receives OTLP
  (`otel-gateway-collector.monitoring.svc:4317` gRPC / `:4318` http) from
  instrumented apps.
- **Operators over raw charts** — `VMSingle`, `OpenTelemetryCollector`,
  `Grafana*` CRs in git; the operators reconcile the actual workloads. Adding a
  dashboard = one `GrafanaDashboard` CR (`grafanaCom.id` or inline JSON).
- **`monitoring` namespace is PSA-privileged** (via `managedNamespaceMetadata`
  on the `victoria-metrics` app) — node-exporter needs hostNetwork/hostPID,
  which Talos's default `baseline` enforcement rejects.
- **node-exporter has `hostRootFsMount` disabled** — the default `/` bind with
  `HostToContainer` propagation fails on Talos's immutable root.
- **Grafana OIDC** — confidential client against Authentik (provider slug
  `grafana`, blueprint-managed). `authentik Admins` → `GrafanaAdmin`, everyone
  else → `Viewer`. One Vault secret (`core/grafana-oidc`) feeds both sides via
  VSO. Grafana itself is stateless (no PVC): dashboards and datasources come
  from CRs, users from OIDC.
- **Grafana operator chart is OCI-only** (`ghcr.io/grafana/helm-charts`) — the
  repo is registered for Argo CD via `configs.repositories` (`enableOCI`) in
  `kubernetes/argocd-apps/argocd.yaml`.

## Bring-up

1. Seed the OIDC secret (once, see `05-bootstrap.md` step 3):

   ```bash
   vault kv put secret/core/grafana-oidc clientSecret="$(openssl rand -base64 48)"
   ```

2. Push to `main`; the apps sync in wave order.

3. Verify:

   ```bash
   kubectl -n monitoring get vmsingle,opentelemetrycollector,grafana
   kubectl -n monitoring get pods

   kubectl -n monitoring port-forward svc/vmsingle-vm 8428:8428 &
   curl -s 'localhost:8428/api/v1/query?query=up' | jq '.data.result[].metric.job'
   # expect: kubelet, cadvisor, node-exporter, kube-state-metrics
   ```

4. Grafana: `https://grafana.internal.homelab0.xyz` → "Sign in with Authentik".
   Dashboards: Node Exporter Full, Kubernetes Views Global/Pods.

## Adding metrics for a new app

- Prometheus endpoint: annotate the pod —
  `prometheus.io/scrape: "true"`, `prometheus.io/port: "<port>"`, optional
  `prometheus.io/path`. The gateway picks it up on the next SD refresh.
- OTel SDK: point OTLP at
  `http://otel-gateway-collector.monitoring.svc:4318` (http) or `:4317` (gRPC).

## Logs (VictoriaLogs)

The `victoria-logs` app (wave 5) deploys a `VLSingle` CR — same VM Operator,
14d retention, 10Gi on `openebs-hostpath`, service
`vlsingle-vl.monitoring.svc:9428`. Collection is the existing `otel-agent`:

- `filelog` receiver tails `/var/log/pods/*/*/*.log` (hostPath, read-only); the
  `container` operator parses the containerd format and extracts
  `k8s.namespace.name` / `k8s.pod.name` / `k8s.container.name` from the path.
- The agent runs as root (`runAsUser: 0`) to read pod logs, and checkpoints
  file offsets in the `file_storage` extension under `/var/lib/otel-agent`
  (hostPath) so restarts neither lose nor duplicate logs.
- `groupbyattrs` promotes the three k8s attributes to resource attributes;
  VictoriaLogs treats resource attributes as **stream fields**, and the
  `VL-Stream-Fields` header pins exactly those three (Loki-label-like, low
  cardinality). Export goes to `/insert/opentelemetry/v1/logs` via `otlphttp`.
- The agent's own pod logs are excluded to avoid a self-feedback loop.

Grafana queries it through the `victoriametrics-logs-datasource` plugin
(installed by the operator from the `GrafanaDatasource` CR, LogsQL in Explore).

Metric names note: scraped metrics are exported with `prometheusremotewrite`
(not OTLP) — VM's OTLP ingestion stores resource attributes as dotted labels
(`service.name` instead of `job`), which breaks community dashboards. Remote
write preserves exact Prometheus semantics. OTLP stays the path for
SDK-instrumented apps via the gateway.

## Later phases

- **Traces** — VictoriaTraces + `otlp` receiver already in place on the gateway;
  add the exporter + Grafana Jaeger datasource when an app emits spans.
- **Alerting** — VMAlert + VMAlertmanager via the VM Operator (`VMRule` CRs).
