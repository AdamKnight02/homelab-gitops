# Dashboards — PKI Platform

Nine dashboards ship as code in
`gitops/monitoring/base/grafana-dashboards/`, all provisioned into the
**PKI Platform** folder. Each lists its purpose, key panels, and the
metrics it depends on.

> **Metric naming contract.** Panels query two classes of metrics:
> 1. **Real, existing metrics** — `up`, `probe_*` (blackbox),
>    `certmanager_*`, `rabbitmq_*`, `kube_*`, `node_*`,
>    `container_*`, `prometheus_tsdb_*`, `vault_*` (OpenBao),
>    `ALERTS`. These work out of the box.
> 2. **Platform app metrics** (`pki_*`, `spire_server_*`) — emitted by
>    cert-api / cert-worker / ca-service / SPIRE. Where a component does
>    not yet expose a metric, the panel renders "No data" — this is the
>    instrumentation backlog, see bottom of this doc.

## 1. Customer PKI Overview — `pki-customer-overview`

Per-customer health at a glance. Template variable `$customer` (multi-select).

| Panel | Query (summary) |
|---|---|
| Certificates Issued (24h) | `increase(pki_certificates_issued_total{customer=~"$customer"}[24h])` |
| Active Certificates | `pki_certificates_active` |
| Expiring < 30d | `pki_certificates_expiring_within_days{days="30"}` |
| Enrollment Error Rate | error/total ratio, thresholded 5%/10% |
| Issuance Rate by Protocol | `rate(pki_certificates_issued_total[5m]) by (protocol)` |
| Enrollments by Result | stacked timeseries |
| Certificates Expiring Soonest | `bottomk(20, not_after - time())` table |

## 2. Certificate Lifecycle — `pki-cert-lifecycle`

Fleet-wide certificate inventory and renewal health, anchored on
cert-manager metrics.

- Ready / Not Ready counts (`certmanager_certificate_ready_condition`)
- Expiring < 7d count, min-days-to-expiry per namespace
- Issued / renewed / revoked event rates per CA
- Full expiry table sorted ascending

## 3. CA / OCSP / CRL Health — `pki-ca-ocsp-crl`

Revocation infrastructure — the panels that matter during an incident.

- Binary status stats: CA up, OCSP probe, CRL probe (green/red mappings)
- CRL age (`time() - pki_crl_last_update_timestamp_seconds`), thresholds 12h/24h
- CA certificate days remaining (red < 90d)
- OCSP latency p50/p95/p99 from blackbox `probe_duration_seconds_bucket`
- OCSP responses by status (good/revoked/unknown)
- CRL publish events + CRL size growth
- CA signing ops rate by CA and key type

## 4. SCEP / ACME Enrollment — `pki-enrollment`

Enrollment protocol health and volume.

- ACME/SCEP probe status (blackbox `acme_directory` / `scep_operation` modules)
- Success-rate stats with 90%/98% thresholds
- Requests by protocol & result (stacked), p95 latency by protocol
- Enrollments by customer (pie), ACME challenge types breakdown

## 5. Platform Health — `pki-platform-health`

Kubernetes-level view of every platform namespace
(`pki|ejbca|openbao|spire|cert-manager|postgres`).

- Pod readiness ratio, restart count, firing alerts (total + critical)
- CPU/memory by namespace
- Component status matrix (`up` table)
- PVC usage with 75%/90% thresholds

## 6. RabbitMQ / Worker Processing — `pki-rabbitmq-workers`

The enrollment pipeline: broker → queues → cert-worker.

- Broker up, total queued, unacked, consumers (red at 0)
- Worker replicas ready, job failures (1h)
- Queue depth per `cert-*` queue, publish/deliver/ack rates
- Worker job duration p95 by job type, jobs by result (stacked)

## 7. SPIFFE / Secrets Health — `pki-spiffe-secrets`

Workload identity and secrets infrastructure.

- SPIRE server up, agents ready (vs node count), SVID issuance rate
- Agent attestation rate vs failures
- OpenBao sealed status (red when sealed), HA count
- OpenBao request rate by mount, PKI issuance by role
- Secrets expiring < 30d

## 8. Infrastructure Capacity — `pki-infra-capacity`

Node/cluster saturation and Prometheus self-monitoring.

- Nodes ready, cluster CPU/mem allocatable
- CPU & memory saturation (percentunit, 70%/90% thresholds)
- Disk usage per node, network I/O
- Prometheus TSDB free space, ingestion rate, head series

## 9. External CA Integrations — `pki-external-ca`

Third-party CA gateway health (DigiCert/Entrust/ADCS-agent/…).

- Gateways reachable count, min TLS-cert days across gateways
- External issuance volume & errors (24h)
- Probe latency per gateway endpoint
- Issuance by provider & result (stacked)
- Endpoint status table (probe_success + cert days)

## Instrumentation backlog

To light up every panel, platform apps should expose:

| Metric | Emitter | Used by |
|---|---|---|
| `pki_certificates_issued_total{customer,protocol,ca_name}` | cert-worker | Overview, Lifecycle |
| `pki_certificates_active`, `pki_certificates_expiring_within_days` | cert-api (inventory job) | Overview |
| `pki_certificate_not_after_timestamp_seconds` | cert-api | Overview table |
| `pki_enrollment_requests_total{protocol,result,customer}` | cert-api | Overview, Enrollment, alerts |
| `pki_enrollment_duration_seconds_bucket` | cert-api | Enrollment |
| `pki_acme_challenges_total{challenge_type,result}` | cert-api | Enrollment |
| `pki_ocsp_responses_total{status}` | ca-service/OCSP | CA/OCSP/CRL |
| `pki_crl_last_update_timestamp_seconds`, `pki_crl_publish_total`, `pki_crl_size_bytes` | ca-service | CA/OCSP/CRL, `CrlStale` alert |
| `pki_ca_certificate_not_after_timestamp_seconds{ca_name}` | ca-service | CA/OCSP/CRL, rollover alert |
| `pki_ca_sign_operations_total{ca_name,key_type}` | ca-service | CA/OCSP/CRL |
| `pki_worker_jobs_total{result}`, `pki_worker_jobs_failed_total`, `pki_worker_job_duration_seconds_bucket{job_type}` | cert-worker | RabbitMQ/Workers |
| `pki_secrets_expiring_within_days` | secrets inventory job | SPIFFE/Secrets |
| `pki_external_ca_issuance_total{ca_provider,result}` | external-ca-gateway | External CA |

Until these exist, the corresponding panels show "No data" — alerts that
depend on them (`CrlStale`, `CaCertificateExpiringSoon`,
`EnrollmentErrorRateHigh`) will be inactive.
