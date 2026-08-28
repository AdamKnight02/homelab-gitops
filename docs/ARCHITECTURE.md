# Machine Identity Platform Architecture

## Overview

The Machine Identity Platform is a comprehensive PKI/certificate management system built on Kubernetes, providing automated certificate lifecycle management, cryptographic inventory, and workload identity.

## Components

### Core Services

| Component | Namespace | Purpose | Technology |
|-----------|-----------|---------|------------|
| cert-api | pki | REST API for certificate management | FastAPI, PostgreSQL |
| cert-worker | pki | Background jobs and discovery | Python, CronJobs |
| ca-service | pki | Certificate authority interface | FastAPI |
| pki-database | pki | Certificate inventory database | PostgreSQL |

### Supporting Infrastructure

| Component | Namespace | Purpose | Technology |
|-----------|-----------|---------|------------|
| EJBCA | ejbca | Certificate Authority | EJBCA CE 9.3.7 |
| OpenBao | openbao | Secret management and PKI | OpenBao 2.6.2 |
| SPIRE | spire | Workload identity | SPIFFE/SPIRE 1.10.0 |
| cert-manager | cert-manager | Kubernetes certificate automation | cert-manager 1.21.1 |
| Prometheus | monitoring | Metrics and alerting | kube-prometheus-stack |
| Argo CD | argocd | GitOps platform | Argo CD |

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Argo CD (GitOps)                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                      PKI Namespace                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  cert-api   │  │ cert-worker │  │    ca-service       │ │
│  │  (REST API) │  │  (CronJobs) │  │  (CA Interface)     │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                    │            │
│         └────────────────┼────────────────────┘            │
│                          │                                 │
│                   ┌──────▼──────┐                          │
│                   │ pki-database│                          │
│                   │ (PostgreSQL)│                          │
│                   └─────────────┘                          │
└─────────────────────────────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
┌────────▼─────┐ ┌────▼────┐ ┌──────▼──────┐
│    EJBCA     │ │ OpenBao │ │   SPIRE     │
│  (CA/PKI)    │ │(Secrets)│ │(Workload ID)│
└──────────────┘ └─────────┘ └─────────────┘
```

## Certificate Lifecycle

1. **Discovery**: cert-worker scans EJBCA, OpenBao, K8s secrets
2. **Inventory**: Stores certificates in pki-database
3. **Monitoring**: Prometheus alerts on expiry, weakness
4. **Renewal**: Automated renewal 30 days before expiry
5. **Revocation**: OCSP/CRL support for status checking
6. **Audit**: All changes logged with attribution

## Security Features

- **mTLS**: Service-to-service mutual TLS
- **SPIFFE**: Workload identity via SPIRE
- **Network Policies**: Default deny, explicit allow
- **Pod Security**: Restricted PSP, non-root containers
- **Policy Engine**: Automated compliance checking
- **PQC Readiness**: Quantum-resistant algorithm assessment

## GitOps Workflow

1. Changes committed to GitHub
2. Argo CD detects changes
3. Automated sync to Kubernetes
4. CI validation on PRs
5. Health checks verify deployment

## Monitoring

- Prometheus metrics from all services
- Grafana dashboards for visualization
- Alertmanager for notifications
- Custom alerts for certificate expiry

## Backup and DR

- Daily automated backups of certificate inventory
- Compressed JSON format for portability
- Restore job for disaster recovery
- Backup PVC with 10Gi storage

## Phase Completion Status

| Phase | Description | Status |
|-------|-------------|--------|
| 8 | PKI Health + Observability | ✅ Complete |
| 9 | SPIFFE/SPIRE workload identity | ✅ Complete |
| 10 | Service-to-service mTLS | ✅ Complete |
| 11 | OpenBao workload authentication | ✅ Complete |
| 12 | Full certificate lifecycle | ✅ Complete |
| 13 | Crypto inventory | ✅ Complete |
| 14 | Certificate discovery | ✅ Complete |
| 15 | Automated renewal | ✅ Complete |
| 16 | Revocation/OCSP/CRL | ✅ Complete |
| 17 | Certificate policy engine | ✅ Complete |
| 18 | PQC readiness | ✅ Complete |
| 19 | Security hardening | ✅ Complete |
| 20 | Backup + DR | ✅ Complete |
| 21 | Failure testing | ✅ Complete |
| 22 | GitOps maturity | ✅ Complete |
| 23 | CI validation | ✅ Complete |
| 24 | Architecture documentation | ✅ Complete |

---

*Generated: 2026-08-28*
*Version: 1.0*
