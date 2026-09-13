# PKI Metrics Documentation

This document catalogs all metrics exposed by the PKI platform observability stack, including native application metrics, blackbox probe metrics, and derived metrics produced by the custom PKI exporter.

---

## Metric Sources

| Source | Description |
|--------|-------------|
| **Native** | Application exposes Prometheus metrics directly |
| **Blackbox Probe** | prometheus-blackbox-exporter probes HTTP/TCP endpoints |
| **PKI Exporter** | Custom lightweight collector (`gitops/monitoring/base/exporters/pki-exporter.yaml`) |
| **cert-manager** | cert-manager exposes certificate lifecycle metrics |
| **RabbitMQ** | RabbitMQ Prometheus plugin exposes queue metrics |
| **OpenBao** | OpenBao `/v1/sys/metrics` endpoint (Prometheus format) |
| **PostgreSQL** | postgres_exporter or direct connectivity checks |
| **kube-state-metrics** | Kubernetes object state (pods, deployments, PVCs) |

---

## EJBCA Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `up{component="ejbca"}` | Gauge | EJBCA pod availability | Native (ServiceMonitor) | Scraped from EJBCA health endpoint |
| `pki_ejbca_up` | Gauge | EJBCA availability (derived) | PKI Exporter | HTTP health probe via exporter |
| `pki_ejbca_ca_status` | Gauge | CA status (1=active, 0=inactive) | PKI Exporter | Derived from EJBCA REST API `/v1/ca` |
| `pki_ejbca_ca_count` | Gauge | Number of configured CAs | PKI Exporter | Derived from EJBCA REST API |
| `pki_ejbca_certificates_issued_total` | Counter | Total certificates issued | PKI Exporter | **Derived**: requires EJBCA DB query or REST search; placeholder in current exporter |
| `pki_ejbca_issuance_failures_total` | Counter | Total issuance failures | PKI Exporter | **Derived**: requires EJBCA audit log parsing; placeholder |
| `pki_ejbca_renewal_failures_total` | Counter | Total renewal failures | PKI Exporter | **Derived**: requires EJBCA audit log parsing; placeholder |
| `pki_ejbca_revocation_events_total` | Counter | Total revocation events | PKI Exporter | **Derived**: requires EJBCA audit log parsing; placeholder |
| `pki_ejbca_certificates_expiring_7d` | Gauge | Certificates expiring in <7 days | PKI Exporter | **Derived**: from cert-manager + EJBCA data |
| `pki_ejbca_certificates_expiring_30d` | Gauge | Certificates expiring in <30 days | PKI Exporter | **Derived**: from cert-manager + EJBCA data |
| `pki_ejbca_certificates_expiring_90d` | Gauge | Certificates expiring in <90 days | PKI Exporter | **Derived**: from cert-manager + EJBCA data |

### EJBCA Derived Metrics — Implementation Notes

EJBCA CE does not natively expose Prometheus metrics for certificate counts, issuance failures, or revocation events. The PKI exporter currently exposes placeholders. To populate these:

1. **Direct database query**: Connect to the EJBCA PostgreSQL database and query `CertificateData` table for counts by status and expiry.
2. **EJBCA REST API search**: Use `/ejbca/ejbca-rest-api/v1/certificate/search` with query parameters for status and expiry windows.
3. **Audit log parsing**: Parse EJBCA audit logs for issuance, renewal, and revocation events (requires log shipping or sidecar).

---

## OCSP Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `probe_success{service="ocsp"}` | Gauge | OCSP responder probe success | Blackbox Probe | HTTP GET to OCSP status endpoint |
| `probe_duration_seconds{service="ocsp"}` | Histogram | OCSP probe latency | Blackbox Probe | Includes DNS, connect, TLS, processing |
| `probe_duration_seconds_bucket{service="ocsp"}` | Histogram | OCSP latency buckets | Blackbox Probe | Used for p50/p95/p99 quantiles |
| `pki_ocsp_responses_total` | Counter | OCSP responses by status | PKI Exporter | **Derived**: requires OCSP responder log parsing or EJBCA API; placeholder |

---

## CRL Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `probe_success{service="crl"}` | Gauge | CRL distribution point probe success | Blackbox Probe | HTTP GET to CRL distribution URL |
| `pki_crl_last_update_timestamp_seconds` | Gauge | CRL last update timestamp | PKI Exporter | **Derived**: requires CRL parsing or EJBCA API; placeholder |
| `pki_crl_publish_total` | Counter | CRL publish events | PKI Exporter | **Derived**: requires CRL generation log parsing; placeholder |
| `pki_crl_size_bytes` | Gauge | CRL size in bytes | PKI Exporter | **Derived**: requires CRL download and size measurement; placeholder |
| `crl_age_seconds` | Gauge | CRL age in seconds | PKI Exporter | **Derived**: `time() - pki_crl_last_update_timestamp_seconds` |
| `crl_next_update_seconds` | Gauge | Seconds until next CRL update | PKI Exporter | **Derived**: requires CRL nextUpdate field parsing |

---

## SCEP Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `probe_success{service="scep"}` | Gauge | SCEP endpoint probe success | Blackbox Probe | HTTP GET to SCEP GetCACaps |
| `pki_enrollment_requests_total{protocol="scep"}` | Counter | Total SCEP requests | PKI Exporter | **Derived**: requires SCEP server metrics or log parsing; placeholder |
| `pki_enrollment_requests_total{protocol="scep", result="success"}` | Counter | Successful SCEP enrollments | PKI Exporter | **Derived**: requires SCEP server metrics; placeholder |
| `pki_enrollment_requests_total{protocol="scep", result="error"}` | Counter | SCEP failures | PKI Exporter | **Derived**: requires SCEP server metrics; placeholder |

---

## ACME Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `probe_success{service="acme"}` | Gauge | ACME directory probe success | Blackbox Probe | HTTP GET to ACME directory endpoint |
| `certmanager_http_acme_client_request_count` | Counter | ACME client requests (cert-manager) | cert-manager | Native cert-manager metric |
| `pki_enrollment_requests_total{protocol="acme"}` | Counter | Total ACME orders | PKI Exporter | **Derived**: requires ACME server metrics or EJBCA API; placeholder |
| `pki_enrollment_requests_total{protocol="acme", result="success"}` | Counter | Successful ACME issuance | PKI Exporter | **Derived**: requires ACME server metrics; placeholder |
| `pki_enrollment_requests_total{protocol="acme", result="error"}` | Counter | ACME failures | PKI Exporter | **Derived**: requires ACME server metrics; placeholder |
| `pki_acme_challenges_total` | Counter | ACME challenges by type and result | PKI Exporter | **Derived**: requires ACME server metrics; placeholder |

---

## RabbitMQ Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `rabbitmq_up` | Gauge | RabbitMQ node availability | RabbitMQ Prometheus plugin | Native |
| `rabbitmq_queue_messages_ready{queue=~"cert-.*"}` | Gauge | Messages ready in queue | RabbitMQ Prometheus plugin | Native |
| `rabbitmq_queue_messages_unacked{queue=~"cert-.*"}` | Gauge | Unacknowledged messages | RabbitMQ Prometheus plugin | Native |
| `rabbitmq_queue_consumers{queue=~"cert-.*"}` | Gauge | Number of consumers | RabbitMQ Prometheus plugin | Native |
| `rabbitmq_queue_messages_published_total` | Counter | Messages published | RabbitMQ Prometheus plugin | Native |
| `rabbitmq_queue_messages_delivered_total` | Counter | Messages delivered | RabbitMQ Prometheus plugin | Native |
| `rabbitmq_queue_messages_acked_total` | Counter | Messages acknowledged | RabbitMQ Prometheus plugin | Native |

---

## cert-worker Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `pki_worker_jobs_total` | Counter | Total jobs processed | cert-worker | **Expected native** — cert-worker should expose this |
| `pki_worker_jobs_failed_total` | Counter | Total failed jobs | cert-worker | **Expected native** — cert-worker should expose this |
| `pki_worker_job_duration_seconds_bucket` | Histogram | Job processing duration | cert-worker | **Expected native** — cert-worker should expose this |
| `pki_worker_job_duration_seconds_sum` | Histogram | Job duration sum | cert-worker | **Expected native** |
| `pki_worker_job_duration_seconds_count` | Histogram | Job duration count | cert-worker | **Expected native** |

> **Note**: cert-worker is a custom component. If it does not yet expose Prometheus metrics, the PKI exporter can derive basic job counts from RabbitMQ queue depth changes, but this is imprecise. The recommended approach is to add Prometheus instrumentation to cert-worker.

---

## cert-api Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `pki_api_requests_total` | Counter | Total API requests | cert-api | **Expected native** — cert-api should expose this |
| `pki_api_failures_total` | Counter | Total API failures | cert-api | **Expected native** — cert-api should expose this |
| `pki_api_latency_seconds_bucket` | Histogram | API latency buckets | cert-api | **Expected native** — cert-api should expose this |

> **Note**: cert-api is a custom component. If it does not yet expose Prometheus metrics, add Prometheus instrumentation (e.g., via a middleware or interceptor).

---

## SPIRE Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `up{component="spire", app_kubernetes_io_name="spire-server"}` | Gauge | SPIRE server availability | Native (ServiceMonitor) | Scraped from SPIRE server metrics endpoint |
| `pki_spire_server_up` | Gauge | SPIRE server availability (derived) | PKI Exporter | TCP connect check to SPIRE server |
| `spire_server_svid_issued_total` | Counter | SVIDs issued | SPIRE | **Expected native** — SPIRE server exposes this |
| `spire_agent_attestation_total` | Counter | Agent attestations | SPIRE | **Expected native** — SPIRE agent exposes this |
| `spire_agent_attestation_failed_total` | Counter | Agent attestation failures | SPIRE | **Expected native** — SPIRE agent exposes this |
| `pki_spire_svid_expiration_seconds` | Gauge | SVID expiration time | PKI Exporter | **Derived**: requires SPIRE server API query; placeholder |

---

## OpenBao Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `vault_core_unsealed` | Gauge | OpenBao unsealed state (1=unsealed) | OpenBao | Native `/v1/sys/metrics` |
| `pki_openbao_up` | Gauge | OpenBao availability (derived) | PKI Exporter | HTTP probe to `/v1/sys/seal-status` |
| `pki_openbao_seal_state` | Gauge | OpenBao seal state (1=sealed, 0=unsealed) | PKI Exporter | Derived from `/v1/sys/seal-status` |
| `pki_openbao_availability` | Gauge | OpenBao availability | PKI Exporter | Derived from seal-status probe |
| `vault_route_create_requests_total` | Counter | OpenBao route create requests | OpenBao | Native `/v1/sys/metrics` |
| `vault_pki_issue_total` | Counter | OpenBao PKI certificate issuance | OpenBao | Native `/v1/sys/metrics` |

---

## PostgreSQL Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `up{component="database"}` | Gauge | PostgreSQL availability | Native (ServiceMonitor) | Scraped from postgres_exporter |
| `pki_postgresql_up` | Gauge | PostgreSQL availability (derived) | PKI Exporter | TCP connect check |
| `pki_postgresql_connections` | Gauge | Active connections | PKI Exporter | **Derived**: requires pg_exporter or direct query; placeholder |
| `pki_postgresql_storage_bytes` | Gauge | Storage usage | PKI Exporter | **Derived**: requires pg_exporter or direct query; placeholder |

---

## cert-manager Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `certmanager_certificate_ready_condition` | Gauge | Certificate ready condition | cert-manager | Native |
| `certmanager_certificate_expiration_timestamp_seconds` | Gauge | Certificate expiration timestamp | cert-manager | Native |
| `certmanager_http_acme_client_request_count` | Counter | ACME client requests | cert-manager | Native |

---

## External CA Metrics

| Metric | Type | Description | Source | Notes |
|--------|------|-------------|--------|-------|
| `probe_success{job=~"external-ca-.*"}` | Gauge | External CA gateway probe success | Blackbox Probe | HTTPS probe to gateway endpoint |
| `probe_ssl_earliest_cert_expiry{job=~"external-ca-.*"}` | Gauge | Gateway TLS cert expiry | Blackbox Probe | TLS certificate expiry from probe |
| `probe_duration_seconds{job=~"external-ca-.*"}` | Histogram | Gateway probe latency | Blackbox Probe | End-to-end probe duration |
| `pki_external_ca_gateway_up` | Gauge | Gateway availability (derived) | PKI Exporter | **Derived**: from blackbox probe results |
| `pki_external_ca_api_reachable` | Gauge | External CA API reachability | PKI Exporter | **Derived**: from blackbox probe results |
| `pki_external_ca_requests_total` | Counter | Total requests to external CA | PKI Exporter | **Derived**: requires gateway metrics; placeholder |
| `pki_external_ca_issuance_total` | Counter | Total issuance via external CA | PKI Exporter | **Derived**: requires gateway metrics; placeholder |
| `pki_external_ca_issuance_failures_total` | Counter | External CA issuance failures | PKI Exporter | **Derived**: requires gateway metrics; placeholder |
| `pki_external_ca_renewal_failures_total` | Counter | External CA renewal failures | PKI Exporter | **Derived**: requires gateway metrics; placeholder |
| `pki_external_ca_revocation_failures_total` | Counter | External CA revocation failures | PKI Exporter | **Derived**: requires gateway metrics; placeholder |
| `pki_external_ca_auth_failures_total` | Counter | External CA authentication failures | PKI Exporter | **Derived**: requires gateway metrics; placeholder |
| `pki_external_ca_rate_limit_total` | Counter | External CA rate limit responses | PKI Exporter | **Derived**: requires gateway metrics; placeholder |

---

## Derived Metrics Summary

The following metrics are **derived** — they are not exposed natively by applications and require the PKI exporter or additional instrumentation:

| Metric | Derivation Method | Production Path |
|--------|-------------------|---------------|
| `pki_ejbca_certificates_issued_total` | EJBCA DB query or REST search | Add EJBCA Prometheus exporter or query `CertificateData` table |
| `pki_ejbca_issuance_failures_total` | EJBCA audit log parsing | Ship EJBCA logs to Loki/Elasticsearch and count events |
| `pki_ejbca_renewal_failures_total` | EJBCA audit log parsing | Same as above |
| `pki_ejbca_revocation_events_total` | EJBCA audit log parsing | Same as above |
| `pki_ejbca_certificates_expiring_*` | cert-manager + EJBCA data join | Query EJBCA DB for expiring certs, or use cert-manager expiry metrics |
| `pki_ocsp_responses_total` | OCSP responder log parsing | Add OCSP responder metrics or parse logs |
| `pki_crl_last_update_timestamp_seconds` | CRL parsing or EJBCA API | Download CRL and parse `thisUpdate` / `nextUpdate` |
| `pki_crl_publish_total` | CRL generation log parsing | Parse EJBCA CRL generation logs |
| `pki_crl_size_bytes` | CRL download and measurement | Download CRL and measure size |
| `pki_enrollment_requests_total` | SCEP/ACME server metrics | Add Prometheus instrumentation to SCEP/ACME endpoints |
| `pki_acme_challenges_total` | ACME server metrics | Add Prometheus instrumentation to ACME server |
| `pki_spire_svid_expiration_seconds` | SPIRE server API query | Query SPIRE server for SVID TTL |
| `pki_postgresql_connections` | PostgreSQL query | Deploy postgres_exporter or query `pg_stat_activity` |
| `pki_postgresql_storage_bytes` | PostgreSQL query | Query `pg_database_size()` |
| `pki_external_ca_*` | External CA gateway metrics | Add Prometheus instrumentation to external-ca-gateway |

---

## Metric Naming Conventions

- **Native metrics**: Use application-specific prefixes (`certmanager_`, `rabbitmq_`, `vault_`, `spire_`)
- **Blackbox probe metrics**: Use `probe_` prefix with `service` or `job` labels
- **PKI exporter metrics**: Use `pki_` prefix with component in the metric name (e.g., `pki_ejbca_`, `pki_openbao_`)
- **Derived metrics**: Clearly documented in this file with derivation method

---

## Adding New Metrics

1. **Native application metrics**: Add Prometheus instrumentation to the application, then create a ServiceMonitor in `gitops/monitoring/base/servicemonitors/`.
2. **Blackbox probes**: Add a Probe CR in `gitops/monitoring/base/blackbox-exporter/probes.yaml` and a corresponding module in `values.yaml`.
3. **PKI exporter metrics**: Extend `gitops/monitoring/base/exporters/pki-exporter.yaml` with a new collector function, and document the metric here.
4. **Recording rules**: For expensive queries, add Prometheus recording rules in `gitops/monitoring/base/alert-rules/` or a dedicated `recording-rules.yaml`.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Agent 8 (PKI Observability) | Initial PKI metrics catalog |
