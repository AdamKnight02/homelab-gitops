# Observability Architecture

## Overview

This document defines the observability architecture for the Machine Identity Platform. Observability is deployed through GitOps (Argo CD) and includes Prometheus, Grafana, Alertmanager, and PKI-specific telemetry.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GRAFANA DASHBOARDS                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Customer    │  │ Certificate │  │ CA / OCSP / │  │ Platform    │        │
│  │ PKI Overview│  │ Lifecycle   │  │ CRL Health  │  │ Health      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ SCEP / ACME │  │ RabbitMQ /  │  │ SPIFFE /    │  │ External CA │        │
│  │ Enrollment  │  │ Worker      │  │ Secrets     │  │ Integrations│        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PROMETHEUS                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Metrics     │  │ Alerting    │  │ Recording   │  │ Service     │        │
│  │ Collection  │  │ Rules       │  │ Rules       │  │ Discovery   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EXPORTERS / PROBES                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ kube-state  │  │ node-       │  │ blackbox    │  │ custom PKI  │        │
│  │ metrics     │  │ exporter    │  │ exporter    │  │ exporter    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PKI PLATFORM COMPONENTS                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ EJBCA       │  │ OpenBao     │  │ SPIRE       │  │ RabbitMQ    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ cert-api    │  │ cert-worker │  │ ca-service  │  │ PostgreSQL  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## GitOps Structure

```
gitops/monitoring/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── prometheus/
│   │   ├── prometheus.yaml
│   │   ├── servicemonitor-prometheus.yaml
│   │   └── prometheus-rules.yaml
│   ├── grafana/
│   │   ├── grafana.yaml
│   │   ├── grafana-datasources.yaml
│   │   └── grafana-dashboards.yaml
│   ├── exporters/
│   │   ├── kube-state-metrics.yaml
│   │   ├── node-exporter.yaml
│   │   └── blackbox-exporter.yaml
│   ├── alerts/
│   │   ├── alertmanager.yaml
│   │   └── alert-rules.yaml
│   └── dashboards/
│       ├── customer-pki-overview.json
│       ├── certificate-lifecycle.json
│       ├── ca-ocsp-crl-health.json
│       ├── scep-acme-enrollment.json
│       ├── platform-health.json
│       ├── rabbitmq-worker.json
│       ├── spiffe-secrets.json
│       └── external-ca-integrations.json
│
└── overlays/
    ├── economy/
    │   ├── kustomization.yaml
    │   ├── prometheus-retention-patch.yaml
    │   ├── grafana-resources-patch.yaml
    │   └── storage-class-patch.yaml
    ├── standard/
    │   ├── kustomization.yaml
    │   ├── prometheus-retention-patch.yaml
    │   ├── grafana-resources-patch.yaml
    │   └── storage-class-patch.yaml
    └── enterprise/
        ├── kustomization.yaml
        ├── prometheus-ha-patch.yaml
        ├── grafana-ha-patch.yaml
        ├── prometheus-retention-patch.yaml
        └── storage-class-patch.yaml
```

---

## PKI Metrics

### EJBCA Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `ejbca_up` | Gauge | EJBCA availability | Blackbox probe |
| `ejbca_ca_status` | Gauge | CA status (1=active, 0=inactive) | EJBCA API |
| `ejbca_certificates_issued_total` | Counter | Total certificates issued | EJBCA API |
| `ejbca_issuance_failures_total` | Counter | Total issuance failures | EJBCA API |
| `ejbca_renewal_failures_total` | Counter | Total renewal failures | EJBCA API |
| `ejbca_revocation_events_total` | Counter | Total revocation events | EJBCA API |
| `ejbca_certificates_expiring_7d` | Gauge | Certificates expiring in <7 days | EJBCA API |
| `ejbca_certificates_expiring_30d` | Gauge | Certificates expiring in <30 days | EJBCA API |
| `ejbca_certificates_expiring_90d` | Gauge | Certificates expiring in <90 days | EJBCA API |

### OCSP Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `ocsp_up` | Gauge | OCSP responder availability | Blackbox probe |
| `ocsp_response_latency_seconds` | Histogram | OCSP response latency | Blackbox probe |
| `ocsp_failures_total` | Counter | OCSP failures | Blackbox probe |

### CRL Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `crl_age_seconds` | Gauge | CRL age in seconds | EJBCA API |
| `crl_next_update_seconds` | Gauge | Seconds until next CRL update | EJBCA API |
| `crl_generation_failures_total` | Counter | CRL generation failures | EJBCA API |

### SCEP Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `scep_requests_total` | Counter | Total SCEP requests | SCEP server |
| `scep_successful_enrollments_total` | Counter | Successful SCEP enrollments | SCEP server |
| `scep_failures_total` | Counter | SCEP failures | SCEP server |

### ACME Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `acme_orders_total` | Counter | Total ACME orders | ACME server |
| `acme_authorizations_total` | Counter | Total ACME authorizations | ACME server |
| `acme_successful_issuance_total` | Counter | Successful ACME issuance | ACME server |
| `acme_failures_total` | Counter | ACME failures | ACME server |

### RabbitMQ Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `rabbitmq_queue_depth` | Gauge | Queue depth | RabbitMQ exporter |
| `rabbitmq_consumers` | Gauge | Number of consumers | RabbitMQ exporter |
| `rabbitmq_failures_total` | Counter | Message failures | RabbitMQ exporter |

### cert-worker Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `cert_worker_jobs_total` | Counter | Total jobs processed | cert-worker |
| `cert_worker_errors_total` | Counter | Total errors | cert-worker |
| `cert_worker_processing_duration_seconds` | Histogram | Processing duration | cert-worker |

### cert-api Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `cert_api_requests_total` | Counter | Total API requests | cert-api |
| `cert_api_failures_total` | Counter | Total API failures | cert-api |
| `cert_api_latency_seconds` | Histogram | API latency | cert-api |

### SPIRE Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `spire_server_up` | Gauge | SPIRE server availability | Blackbox probe |
| `spire_svid_expiration_seconds` | Gauge | SVID expiration time | SPIRE API |

### OpenBao Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `openbao_up` | Gauge | OpenBao availability | Blackbox probe |
| `openbao_seal_state` | Gauge | Seal state (1=sealed, 0=unsealed) | OpenBao API |

### PostgreSQL Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `postgresql_up` | Gauge | PostgreSQL availability | PostgreSQL exporter |
| `postgresql_connections` | Gauge | Active connections | PostgreSQL exporter |
| `postgresql_storage_bytes` | Gauge | Storage usage | PostgreSQL exporter |

### External CA Metrics

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `external_ca_gateway_up` | Gauge | Gateway availability | Blackbox probe |
| `external_ca_api_reachable` | Gauge | External CA API reachability | Blackbox probe |
| `external_ca_requests_total` | Counter | Total requests | External CA gateway |
| `external_ca_issuance_total` | Counter | Total issuance | External CA gateway |
| `external_ca_issuance_failures_total` | Counter | Issuance failures | External CA gateway |
| `external_ca_renewal_failures_total` | Counter | Renewal failures | External CA gateway |
| `external_ca_revocation_failures_total` | Counter | Revocation failures | External CA gateway |
| `external_ca_api_latency_seconds` | Histogram | API latency | External CA gateway |
| `external_ca_auth_failures_total` | Counter | Authentication failures | External CA gateway |
| `external_ca_rate_limit_total` | Counter | Rate limit responses | External CA gateway |
| `external_ca_issuance_duration_seconds` | Histogram | Issuance duration | External CA gateway |

---

## Dashboards

### Customer PKI Overview

**Purpose:** High-level view of PKI platform health for a customer.

**Panels:**
- Platform status (all components up/down)
- Certificates issued (last 24h, 7d, 30d)
- Certificates expiring (<7d, <30d, <90d)
- CA status (Root CA, Issuing CA)
- Recent issuance failures
- Recent revocation events

### Certificate Lifecycle

**Purpose:** Track certificate lifecycle from request to revocation.

**Panels:**
- Certificate requests (rate)
- Certificate issuance (rate)
- Certificate renewal (rate)
- Certificate revocation (rate)
- Average issuance time
- Average renewal time

### CA / OCSP / CRL Health

**Purpose:** Monitor CA infrastructure health.

**Panels:**
- CA status (up/down)
- OCSP responder status (up/down, latency)
- CRL age and next update
- CRL generation failures
- OCSP failures

### SCEP / ACME Enrollment

**Purpose:** Monitor enrollment protocol health.

**Panels:**
- SCEP requests (rate)
- SCEP successful enrollments (rate)
- SCEP failures (rate)
- ACME orders (rate)
- ACME successful issuance (rate)
- ACME failures (rate)

### Platform Health

**Purpose:** Monitor overall platform health.

**Panels:**
- All components up/down
- Pod restarts
- Resource usage (CPU, memory)
- Storage usage
- Network traffic

### RabbitMQ / Worker Processing

**Purpose:** Monitor message queue and worker health.

**Panels:**
- Queue depth
- Consumer count
- Message rate
- Worker jobs processed
- Worker errors
- Worker processing duration

### SPIFFE / Secrets Health

**Purpose:** Monitor workload identity and secrets health.

**Panels:**
- SPIRE server status
- SVID expiration
- OpenBao status
- OpenBao seal state
- Secret access rate

### External CA Integrations

**Purpose:** Monitor external CA integration health.

**Panels:**
- Provider status (DigiCert, Sectigo, Let's Encrypt, etc.)
- Requests per minute
- Success rate
- Failure rate
- Latency
- Rate limits
- Authentication failures

---

## Alerting Rules

### Critical Alerts

| Alert | Condition | Action |
|-------|-----------|--------|
| `EJBCADown` | `ejbca_up == 0` for 5m | Page on-call |
| `OpenBaoSealed` | `openbao_seal_state == 1` for 1m | Page on-call |
| `SPIREServerDown` | `spire_server_up == 0` for 5m | Page on-call |
| `PostgreSQLDown` | `postgresql_up == 0` for 5m | Page on-call |
| `RabbitMQDown` | `rabbitmq_up == 0` for 5m | Page on-call |

### Warning Alerts

| Alert | Condition | Action |
|-------|-----------|--------|
| `CertificatesExpiringSoon` | `ejbca_certificates_expiring_7d > 0` | Notify team |
| `OCSPLatencyHigh` | `ocsp_response_latency_seconds > 5` for 10m | Notify team |
| `CRLStale` | `crl_age_seconds > 86400` | Notify team |
| `ExternalCAAuthFailures` | `external_ca_auth_failures_total > 10` in 5m | Notify team |
| `ExternalCARateLimited` | `external_ca_rate_limit_total > 0` in 5m | Notify team |

---

## Tier-Specific Configuration

### Economy

| Setting | Value |
|---------|-------|
| Prometheus retention | 7 days |
| Prometheus storage | 10Gi |
| Grafana replicas | 1 |
| Prometheus replicas | 1 |
| Alertmanager replicas | 1 |
| Persistent storage | Yes (minimal) |
| HA | No |

### Standard

| Setting | Value |
|---------|-------|
| Prometheus retention | 30 days |
| Prometheus storage | 50Gi |
| Grafana replicas | 1 |
| Prometheus replicas | 1 |
| Alertmanager replicas | 1 |
| Persistent storage | Yes |
| HA | No |

### Enterprise

| Setting | Value |
|---------|-------|
| Prometheus retention | 90 days |
| Prometheus storage | 200Gi |
| Grafana replicas | 2 |
| Prometheus replicas | 2 |
| Alertmanager replicas | 2 |
| Persistent storage | Yes |
| HA | Yes |
| Remote storage | Optional (Thanos/Cortex) |

---

## Customer Isolation

### Namespace Isolation

Each customer's monitoring stack runs in a dedicated namespace:

```
monitoring-<customer-id>/
├── prometheus
├── grafana
├── alertmanager
└── exporters
```

### Data Isolation

- Prometheus: Customer-specific scrape configs and service discovery
- Grafana: Customer-specific datasources and dashboards
- Alertmanager: Customer-specific routing and receivers

### Access Control

- Grafana: Customer-specific organizations and teams
- Prometheus: Customer-specific remote write (if using remote storage)
- Alertmanager: Customer-specific notification channels

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial observability architecture |
