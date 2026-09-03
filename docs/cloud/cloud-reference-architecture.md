# Cloud Reference Architecture

> **Status**: Logical reference architecture for multi-cloud PKI platform

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Client / Application                    │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Web App   │  │   Mobile    │  │     Service         │ │
│  │             │  │    App      │  │    (mTLS)           │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                    │            │
│         └────────────────┼────────────────────┘            │
│                          │                                 │
│                          ▼                                 │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Certificate API (REST)                  │  │
│  │         Authentication / Authorization               │  │
│  │              (SPIFFE / Kubernetes)                   │  │
│  └─────────────────────────┬───────────────────────────┘  │
│                            │                               │
└────────────────────────────┼───────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      Message Queue (RabbitMQ)               │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              certificate_requests queue              │   │
│  │              certificate_renewals queue              │   │
│  │              certificate_revocations queue           │   │
│  └─────────────────────────────────────────────────────┘   │
│                            │                                │
└────────────────────────────┼───────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Certificate Worker                       │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Request   │  │   Renewal   │  │     Revocation      │ │
│  │  Processor  │  │  Processor  │  │     Processor       │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                    │            │
│         └────────────────┼────────────────────┘            │
│                          │                                 │
│                          ▼                                 │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              CA Abstraction Layer                    │  │
│  │         (EJBCA / OpenBao / External CA)             │  │
│  └─────────────────────────┬───────────────────────────┘  │
│                            │                               │
└────────────────────────────┼───────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                         EJBCA PKI                           │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Root CA   │  │  Issuing CA │  │   Certificate       │ │
│  │             │  │             │  │   Profiles          │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │    OCSP     │  │    CRL      │  │   Crypto Tokens     │ │
│  │  Responder  │  │  Distribution│  │   (HSM/Software)    │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      PostgreSQL Database                     │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  EJBCA Data │  │   Audit     │  │   Inventory         │ │
│  │             │  │    Log      │  │   (Certificates)    │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Supporting Infrastructure

```
┌─────────────────────────────────────────────────────────────┐
│                    Workload Identity (SPIRE)                │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ SPIRE Server│  │ SPIRE Agent │  │   OIDC Discovery    │ │
│  │ (StatefulSet)│  │ (DaemonSet) │  │   Provider          │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
│  SPIFFE IDs:                                                 │
│  - spiffe://pki-cloudlab.local/ns/pki/sa/cert-api          │
│  - spiffe://pki-cloudlab.local/ns/pki/sa/cert-worker       │
│  - spiffe://pki-cloudlab.local/ns/pki/sa/ca-service        │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Secrets Management (OpenBao)              │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  PKI Engine │  │   KV Store  │  │  Kubernetes Auth    │ │
│  │             │  │             │  │                     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  Certificate Management (cert-manager)      │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Issuer    │  │ Certificate │  │   ClusterIssuer     │ │
│  │             │  │             │  │                     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Certificate Issuance

```
1. Client → cert-api (HTTP/REST)
2. cert-api → AuthN/AuthZ (SPIFFE verification)
3. cert-api → RabbitMQ (queue request)
4. cert-worker ← RabbitMQ (consume request)
5. cert-worker → CA Abstraction Layer
6. CA Abstraction → EJBCA (issue certificate)
7. EJBCA → PostgreSQL (store certificate data)
8. cert-worker → Inventory (store certificate metadata)
9. cert-worker → Audit (log event)
10. cert-worker → RabbitMQ (notify completion)
11. cert-api ← RabbitMQ (return certificate to client)
```

### Certificate Renewal

```
1. cert-api (monitor) detects expiry
2. cert-api → RabbitMQ (queue renewal)
3. cert-worker ← RabbitMQ (process renewal)
4. cert-worker → CA Abstraction (reissue)
5. CA Abstraction → EJBCA (new certificate)
6. cert-worker → Inventory (update record)
7. cert-worker → Audit (log renewal)
```

### Certificate Revocation

```
1. Admin → cert-api (revocation request)
2. cert-api → RabbitMQ (queue revocation)
3. cert-worker ← RabbitMQ (process revocation)
4. cert-worker → CA Abstraction (revoke)
5. CA Abstraction → EJBCA (update CRL)
6. cert-worker → Inventory (update status)
7. cert-worker → Audit (log revocation)
8. EJBCA publishes updated CRL
```

## Component Responsibilities

| Component | Responsibility | Technology |
|-----------|---------------|------------|
| cert-api | REST API for certificate operations | Python/FastAPI |
| cert-worker | Background processing | Python/Celery |
| CA Abstraction | Unified CA interface | Python library |
| EJBCA | Certificate issuance | Java/Tomcat |
| PostgreSQL | Data persistence | PostgreSQL 15 |
| RabbitMQ | Message queuing | RabbitMQ 3.12 |
| OpenBao | Secrets management | OpenBao 2.0 |
| SPIRE | Workload identity | SPIRE 1.8 |
| cert-manager | TLS automation | cert-manager 1.14 |
| Argo CD | GitOps | Argo CD 2.11 |
| K3s | Kubernetes | K3s 1.30 |

## Scaling Considerations

### Horizontal Scaling

```
cert-api: 2+ replicas (load balanced)
cert-worker: 2+ replicas (queue consumers)
EJBCA: 1 replica (stateful, can cluster)
PostgreSQL: 1 replica (can use HA setup)
RabbitMQ: 3 replicas (cluster for HA)
```

### Resource Requirements

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| K3s | 1 | 2GB | 20GB |
| EJBCA | 1 | 2GB | 10GB |
| PostgreSQL | 0.5 | 1GB | 10GB |
| RabbitMQ | 0.5 | 1GB | 5GB |
| cert-api | 0.25 | 256MB | — |
| cert-worker | 0.25 | 256MB | — |
| OpenBao | 0.5 | 512MB | 5GB |
| SPIRE | 0.25 | 256MB | 1GB |
| **Total** | **~4** | **~8GB** | **~50GB** |

## Cloud Portability

All components are containerized and deployed via Kubernetes manifests, making them portable across:
- Local homelab (K3s on libvirt VM)
- Azure (K3s on Azure VM)
- AWS (K3s on EC2)
- Any other Kubernetes cluster
