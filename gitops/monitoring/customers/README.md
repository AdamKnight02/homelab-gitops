# Customer Monitoring Onboarding

To onboard a new customer to platform monitoring:

```bash
cp -r gitops/monitoring/customers/_template gitops/monitoring/customers/acme-corp
cd gitops/monitoring/customers/acme-corp
sed -i 's/__CUSTOMER_ID__/acme-corp/g; s/__TIER__/standard/g; s/__CUSTOMER_ALERT_EMAIL__/pki-alerts@acme.example/g' customer-overlay.yaml
```

Then register the customer in the Argo CD ApplicationSet
(`gitops/monitoring/argocd/applicationset-customers.yaml`) — it auto-discovers
any directory under `customers/` that is not `_template`.

## Isolation model

| Layer | Mechanism |
|---|---|
| Metrics | `customer` label stamped via relabeling; dashboards filter on it |
| Alerts | `AlertmanagerConfig` per customer routes on `customer=<id>` |
| Dashboards | Shared platform dashboards with `$customer` variable; enterprise tier gets per-customer Grafana org |
| Storage | Shared TSDB (economy/standard); per-tenant remote write (enterprise) |
| Network | Customer namespaces have default-deny NetworkPolicy; only Prometheus scrape port allowed |
