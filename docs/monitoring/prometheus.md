# Prometheus — PKI Platform Monitoring

This document covers the Prometheus deployment for the machine-identity
platform: architecture, GitOps layout, tiers, storage, and operations.

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│ Argo CD                                                        │
│  ├─ Application: monitoring            (kube-prometheus-stack) │
│  ├─ Application: monitoring-blackbox   (blackbox exporter)     │
│  ├─ Application: monitoring-extras     (monitors/rules/dash)   │
│  ├─ ApplicationSet: monitoring-matrix  (tier × provider)       │
│  └─ ApplicationSet: monitoring-customers (per-customer)        │
└────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ namespace: monitoring                                       │
│  Prometheus Operator ──► Prometheus (TSDB on PVC)           │
│  Alertmanager (clustered per tier)                          │
│  Grafana (dashboards sidecar-loaded from Git)               │
│  kube-state-metrics · node-exporter · blackbox exporter     │
└─────────────────────────────────────────────────────────────┘
        │ scrapes (ServiceMonitor/PodMonitor/Probe, label-selected)
        ▼
  pki · ejbca · cert-manager · rabbitmq · spire · openbao · postgres
  + customer namespaces (opt-in via labels)
```

The stack is deployed with the
[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
Helm chart through Argo CD's multi-source pattern — the same convention
already used by `apps/openbao` and `apps/ejbca` in this repo.

## GitOps layout

```
gitops/monitoring/
├── base/
│   ├── prometheus-stack/     # Helm values (env-neutral) + admin secret shape
│   ├── blackbox-exporter/    # probe modules + Probe CRs (OCSP/CRL/ACME/SCEP)
│   ├── servicemonitors/      # ServiceMonitors/PodMonitors for platform apps
│   ├── alert-rules/          # PrometheusRule CRs (pki-alerts.yaml)
│   └── grafana-dashboards/   # 9 dashboards as ConfigMaps (sidecar-loaded)
├── overlays/
│   ├── economy/              # 3d retention, 5Gi, 1 replica, 60s scrape
│   ├── standard/             # 15d retention, 50Gi, 2x Alertmanager
│   └── enterprise/           # 30d + remote write, 2x Prom, 3x AM, 200Gi, HA
├── providers/
│   ├── homelab/              # k3s local-path, NodePort, node-exporter on
│   ├── azure/                # AKS managed-csi, internal LB, Entra ID auth
│   └── aws/                  # EKS gp3, NLB, IRSA hooks
├── customers/
│   ├── _template/            # copy-per-customer overlay (see README)
│   └── README.md
└── argocd/
    ├── application.yaml            # static app (homelab/economy default)
    ├── application-blackbox.yaml
    ├── application-extras.yaml
    └── applicationsets.yaml        # matrix + customer auto-discovery
```

**Layering order:** `base → tier overlay → provider overlay → customer overlay`.
Helm values merge in that order in the Application/ApplicationSet
`valueFiles` list; later files win.

## Tier model

| Tier | Retention | TSDB | Replicas (Prom/AM/Grafana) | Scrape | Remote write |
|---|---|---|---|---|---|
| economy | 3d | 5Gi | 1 / 1 / 1 | 60s | — |
| standard | 15d | 50Gi | 1 / 2 / 1 | 30s | optional |
| enterprise | 30d local | 200Gi | 2 / 3 / 2 | 15s | required (Thanos/Mimir/AMP) |

Enterprise enables the Thanos sidecar (`thanosService.enabled`) and
`replicaExternalLabelName` for dedup at the remote store. Remote-write
credentials are referenced via Secret, never inline.

## Customer isolation

1. **Opt-in scraping** — Prometheus only selects monitors labeled
   `monitoring.pki.platform.io/enabled: "true"`. Customer namespaces add
   monitors via their overlay; the platform team controls the selector.
2. **Metric labeling** — every customer sample is stamped with
   `customer=<id>` and `tier=<tier>` via relabeling in the customer's
   ServiceMonitor (see `customers/_template/customer-overlay.yaml`).
3. **Alert routing** — per-customer `AlertmanagerConfig` matches
   `customer=<id>` and routes to the customer's receiver.
4. **Dashboards** — shared dashboards expose a `$customer` variable;
   enterprise tier can map customers to dedicated Grafana orgs with a
   per-tenant datasource.
5. **Network** — customer namespaces keep default-deny NetworkPolicy;
   only the monitoring namespace may reach the metrics port.

## Secrets

| Secret | Purpose | Management |
|---|---|---|
| `grafana-admin` | Grafana initial admin | SealedSecret/ExternalSecret per env; base file documents shape only — **change `changeme-grafana-admin` before first deploy** |
| `remote-write-auth` | Enterprise remote write | ExternalSecret (OpenBao) |
| Alertmanager receivers | Customer notification creds | Referenced from `AlertmanagerConfig` via Secret |
| OAuth (Azure AD) | Grafana SSO | `GF_AUTH_AZUREAD_CLIENT_SECRET` env from Secret |

## Operations

**Deploy (homelab):**
```bash
kubectl apply -f gitops/monitoring/argocd/application.yaml
kubectl apply -f gitops/monitoring/argocd/application-blackbox.yaml
kubectl apply -f gitops/monitoring/argocd/application-extras.yaml
```

**Access (homelab NodePort):**
- Grafana: `http://<node>:30030` (admin / value of `grafana-admin` secret)
- Prometheus: `http://<node>:30090`
- Alertmanager: `http://<node>:30093`

**Change tiers:** edit the `valueFiles` list in `application.yaml` (or
deploy the ApplicationSet matrix) and sync.

**Add a scrape target:** create a ServiceMonitor/PodMonitor with
`monitoring.pki.platform.io/enabled: "true"` in `base/servicemonitors/`
(platform components) or in the customer overlay (customer workloads).

**Storage growth:** watch the `PrometheusStorageAlmostFull` alert; grow the
PVC (storage class must allow expansion) or reduce `retention` /
`retentionSize` in the tier overlay.

**Upgrade:** bump `targetRevision` of the chart in
`gitops/monitoring/argocd/application.yaml`. CRDs are managed by the chart
(`crds.enabled: true`); ServerSideApply is enabled to handle large CRDs.
