# Grafana — PKI Platform

Grafana is deployed as part of `kube-prometheus-stack` and is fully
GitOps-managed. Dashboards and datasources are provisioned from Git via the
Grafana sidecar containers — the UI is read-only for provisioned content.

## How provisioning works

```
gitops/monitoring/base/grafana-dashboards/*.yaml
        │  ConfigMaps labeled grafana_dashboard: "1"
        ▼
Grafana sidecar (kiwigrid/k8s-sidecar) watches the label
        ▼
writes JSON into /tmp/dashboards → Grafana provisions from disk
        ▼
dashboards appear in folder from annotation grafana_folder: "PKI Platform"
```

Datasources work the same way with the `grafana_datasource: "1"` label
(used by the customer overlay to add per-customer datasources).

**Consequences:**
- UI edits to provisioned dashboards are lost on pod restart. Export JSON
  and commit it back to `gitops/monitoring/base/grafana-dashboards/`.
- Dashboard UIDs are stable (`pki-customer-overview`, `pki-cert-lifecycle`,
  …) so alert annotations and links can reference them.

## Access & authentication

| Environment | URL | Auth |
|---|---|---|
| homelab | `http://<node>:30030` (NodePort) | local admin from `grafana-admin` Secret |
| azure | internal LoadBalancer | Entra ID OAuth (`auth.azuread`) |
| aws | internal NLB | SSO via configured IdP / IAM |

The base values set `serve_from_sub_path: true` with root URL
`/grafana/` so an Ingress can front it later without config changes.

## Persistence

Grafana's SQLite database (users, orgs, preferences, API keys) is on a PVC
sized per tier (1Gi economy → 10Gi enterprise). Enterprise runs 2 replicas —
for true HA at that tier, switch Grafana to an external Postgres backend by
setting `grafana.env.GF_DATABASE_*` via Secret in the enterprise overlay.

## Customer isolation in Grafana

- **economy/standard:** one Grafana org. Customers see shared dashboards
  filtered by the `$customer` template variable; per-customer datasources
  (`Prometheus-<customer-id>`) are provisioned from the customer overlay
  and can be restricted with folder permissions.
- **enterprise:** map each customer to a dedicated Grafana **Organization**
  with its own datasource pointed at their remote-write tenant. Org
  provisioning is done via the Grafana API/Terraform in the customer
  onboarding pipeline (out of scope for the base chart).

## Adding or changing a dashboard

1. Edit or add a ConfigMap in `gitops/monitoring/base/grafana-dashboards/`.
2. Keep `metadata.labels.grafana_dashboard: "1"` and set
   `annotations.grafana_folder`.
3. Give the dashboard a stable, unique `uid`.
4. Validate locally: `kubectl kustomize gitops/monitoring/base/grafana-dashboards`.
5. Commit — Argo CD syncs, the sidecar picks up the change within ~30s.

## Datasources

| Name | Type | Source |
|---|---|---|
| Prometheus (default) | prometheus | chart-built-in → in-cluster Prometheus |
| Prometheus-\<customer\> | prometheus | customer overlay ConfigMap |
| Alertmanager | alertmanager | chart-built-in |

Loki/Tempo can be added later by dropping datasource ConfigMaps with the
`grafana_datasource` label into `base/` — no chart changes needed.

## Troubleshooting

- **Dashboard not appearing:** check the sidecar logs
  (`kubectl logs -n monitoring deploy/monitoring-grafana -c grafana-sc-dashboard`)
  and confirm the ConfigMap label value is exactly `"1"`.
- **JSON error:** the sidecar skips invalid files; validate with
  `python3 -c "import json; json.loads(...)"` before committing.
- **Login loop behind proxy:** verify `root_url`/`serve_from_sub_path`
  match the Ingress path.
