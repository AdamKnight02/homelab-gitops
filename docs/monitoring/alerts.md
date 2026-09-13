# Alerts — PKI Platform

Alert rules live in `gitops/monitoring/base/alert-rules/pki-alerts.yaml` as
a versioned `PrometheusRule` CR — not in Helm values — so they diff cleanly
in Git and can be reviewed like code.

## Severity model

| Severity | Meaning | Response |
|---|---|---|
| critical | Service-impacting (CA/OCSP/CRL down, queue stalled, OpenBao sealed) | Page immediately, repeat 1h |
| warning | Degrading (high error rate, backlog, cert expiring, agent missing) | Business-hours investigation, repeat 4h |
| info | Planning signals (CA cert < 90d) | Ticket, no page |

## Alert groups

### `pki.ca-health`
| Alert | Condition | For |
|---|---|---|
| CertificateAuthorityDown | `up{component="ejbca"} == 0` | 2m |
| OcspResponderDown | `probe_success{service="ocsp"} == 0` | 2m |
| OcspResponderSlow | OCSP p95 > 1s | 10m |
| CrlDistributionDown | `probe_success{service="crl"} == 0` | 5m |
| CrlStale | CRL age > 24h | 1h |

### `pki.certificate-lifecycle`
| Alert | Condition | For |
|---|---|---|
| CertificateExpiringSoon | cert-manager cert < 7d and Ready | 1h |
| CertificateRenewalFailing | cert Ready=False | 30m |
| CaCertificateExpiringSoon | CA cert < 90d (info) | 1h |
| EnrollmentErrorRateHigh | error ratio > 10% per protocol/customer | 15m |

### `pki.queue-processing`
| Alert | Condition | For |
|---|---|---|
| RabbitMQQueueBacklog | `cert-*` queue > 500 ready messages | 15m |
| RabbitMQQueueNoConsumers | `cert-*` queue consumers == 0 | 5m |
| RabbitMQNodeDown | `rabbitmq_up == 0` | 2m |

### `pki.workload-identity`
| Alert | Condition | For |
|---|---|---|
| SpireServerDown | SPIRE server `up == 0` | 2m |
| SpireAgentUnavailable | ready agents < node count | 10m |
| OpenBaoSealed | `vault_core_unsealed == 0` | 5m |

### `pki.external-ca`
| Alert | Condition | For |
|---|---|---|
| ExternalCaGatewayDown | `probe_success{job=~"external-ca-.*"} == 0` | 5m |
| ExternalCaCertificateExpiring | gateway TLS cert < 30d | 1h |

### `pki.platform-capacity`
| Alert | Condition | For |
|---|---|---|
| PrometheusStorageAlmostFull | TSDB PVC < 15% free | 1h |
| PkiDatabaseDown | postgres `up == 0` | 2m |

## Routing

Alertmanager routing (base config in
`base/prometheus-stack/values.yaml`):

```
root route (group_by: alertname, namespace, customer)
├── customer != ""        → per-customer AlertmanagerConfig receiver (continue)
└── severity=critical & component=ca|ocsp|crl|hsm → pki-critical (repeat 1h)
```

- **Platform alerts** go to `platform-default` / `pki-critical` receivers.
  Wire these to email/Slack/PagerDuty via environment-specific
  `AlertmanagerConfig` secrets — never commit credentials.
- **Customer alerts** carry the `customer` label (stamped at scrape time)
  and are matched by the customer's `AlertmanagerConfig` from
  `gitops/monitoring/customers/<id>/`.
- **Inhibition:** a firing critical suppresses same-alertname warnings in
  the same namespace.

## Adding an alert

1. Add the rule to the appropriate group in `pki-alerts.yaml` (or a new
   `PrometheusRule` with the `monitoring.pki.platform.io/enabled: "true"`
   label).
2. Always set: `severity`, `component`, `team` labels and
   `summary`/`description`/`runbook` annotations.
3. Validate: `kubectl kustomize gitops/monitoring/base/alert-rules`.
4. Commit — Argo CD syncs; Prometheus Operator reloads rules automatically.

## Testing

```bash
# Port-forward Alertmanager and check routing
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093

# Fire a synthetic alert
kubectl run amtool --rm -it --image=prom/alertmanager:latest -- \
  amtool --alertmanager.url=http://monitoring-kube-prometheus-alertmanager.monitoring:9093 \
  alert add alertname=TestAlert severity=warning customer=demo \
  summary="synthetic test" --generator-url=http://test

# Silence during maintenance
amtool silence add alertname=CertificateAuthorityDown --duration=2h --comment="CA upgrade"
```

## Dependencies

Some rules depend on platform app metrics that may not exist yet
(`pki_crl_last_update_timestamp_seconds`,
`pki_ca_certificate_not_after_timestamp_seconds`,
`pki_enrollment_requests_total`). Rules referencing missing metrics simply
never fire — see the instrumentation backlog in
[docs/monitoring/dashboards.md](dashboards.md#instrumentation-backlog).
