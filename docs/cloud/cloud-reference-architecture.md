# Cloud-Neutral PKI Reference Architecture

## Overview

This document defines the logical reference architecture for the Machine Identity Platform, designed to be portable across:
- **Local Homelab** (libvirt/KVM + K3s)
- **Azure** (VM + K3s — PLAN-ONLY)
- **AWS** (EC2 + K3s — PLAN-ONLY or ephemeral test)

## Design Philosophy

1. **Cloud-Neutral Workloads**: All PKI platform components run as containerized workloads on Kubernetes
2. **Infrastructure as Code**: Terraform provisions cloud infrastructure; GitOps (Argo CD) manages platform workloads
3. **Identity-First Security**: SPIFFE/SPIRE workload identity + OpenBao secrets management + mTLS everywhere
4. **Reproducibility**: Same Git repository, same manifests, different infrastructure backends
5. **Cost Consciousness**: Avoid expensive managed services; prefer portable open-source components

---

## Logical Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLIENT / APPLICATION                               │
│                         (mTLS Authenticated)                                 │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │ mTLS
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CERTIFICATE API (cert-api)                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   REST API  │  │   AuthN     │  │   AuthZ     │  │  Validation │        │
│  │   (FastAPI) │  │ (SPIFFE/    │  │ (OpenBao    │  │  (Schema/   │        │
│  │             │  │  K8s SA)    │  │  policies)  │  │   Policy)   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │ AMQP 0-9-1
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          RABBITMQ MESSAGE QUEUE                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │   Exchange  │  │    Queue    │  │  Routing    │                         │
│  │ cert.request│  │ cert.issue  │  │   Keys      │                         │
│  │ cert.renew  │  │ cert.revoke │  │             │                         │
│  │ cert.revoke │  │ cert.expire │  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CERTIFICATE WORKER (cert-worker)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Consumer  │  │   Policy    │  │   CA Abstr  │  │   Notifier  │        │
│  │   (Pika)    │  │   Engine    │  │   Layer     │  │  (Events)   │        │
│  │             │  │             │  │             │  │             │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CA ABSTRACTION LAYER (ca-service)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   EJBCA     │  │   EST       │  │   ACME      │  │   CMP       │        │
│  │   Client    │  │   Client    │  │   Client    │  │   Client    │        │
│  │             │  │             │  │             │  │             │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EJBCA CA PLATFORM                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         TRUST HIERARCHY                              │    │
│  │  ┌─────────────┐                                                    │    │
│  │  │  Root CA    │  (LabRootCA — offline capable, 10yr lifetime)      │    │
│  │  │  (Offline)  │                                                    │    │
│  │  └──────┬──────┘                                                    │    │
│  │         │ signs                                                     │    │
│  │         ▼                                                           │    │
│  │  ┌─────────────┐                                                    │    │
│  │  │ Issuing CA  │  (LabIssuingCA — online, 5yr lifetime)             │    │
│  │  │  (Online)   │                                                    │    │
│  │  └──────┬──────┘                                                    │    │
│  │         │ signs end-entity certs                                    │    │
│  │         ▼                                                           │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │    │
│  │  │  TLS Certs  │  │  Client     │  │  SPIFFE     │                 │    │
│  │  │  (Servers)  │  │  Certs      │  │  SVIDs      │                 │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   OCSP      │  │    CRL      │  │   EST       │  │   SCEP      │        │
│  │  Responder  │  │  Dist Point │  │  Server     │  │  Server     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            POSTGRESQL DATABASE                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │   EJBCA     │  │   PKI       │  │   Audit     │                         │
│  │   Data      │  │   Inventory │  │   Log       │                         │
│  │             │  │             │  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Supporting Security Layer

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WORKLOAD IDENTITY & SECURITY                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        SPIRE / SPIFFE                                │    │
│  │                                                                      │    │
│  │   SPIRE Server                       SPIRE Agent (DaemonSet)         │    │
│  │   ┌─────────────┐                    ┌─────────────┐                 │    │
│  │   │  Node       │◄──────gRPC─────────│  Workload   │                 │    │
│  │   │  Attestor   │    (PSAT/K8s)      │  Attestor   │                 │    │
│  │   │             │                    │  (K8s/Unix) │                 │    │
│  │   └──────┬──────┘                    └──────┬──────┘                 │    │
│  │          │                                   │                       │    │
│  │          ▼                                   ▼                       │    │
│  │   ┌─────────────┐                    ┌─────────────┐                 │    │
│  │   │  SVID       │───────inject──────►│  Workload   │                 │    │
│  │   │  Issuer     │   (CSI/Secret)     │  Pod        │                 │    │
│  │   └─────────────┘                    └─────────────┘                 │    │
│  │                                                                      │    │
│  │   Trust Domain: pki-cloudlab.local (cloud-neutral)                   │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        OPENBAO SECRETS                               │    │
│  │                                                                      │    │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐   │    │
│  │   │   KV Store  │  │   PKI       │  │   Transit   │  │  Auth   │   │    │
│  │   │  (Secrets)  │  │  (Internal) │  │ (Encryption)│  │ Methods │   │    │
│  │   └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘   │    │
│  │                                                                      │    │
│  │   Auth: Kubernetes SA, SPIFFE mTLS, Token                           │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        CERT-MANAGER                                  │    │
│  │                                                                      │    │
│  │   Automates TLS certificate lifecycle for ingress/services           │    │
│  │   Integrates with EJBCA via custom issuer (future)                   │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Portability Matrix

| Component | Homelab | Azure | AWS | Portability | Notes |
|-----------|---------|-------|-----|-------------|-------|
| **Infrastructure** | libvirt/KVM | Terraform VM | Terraform EC2 | Provider-specific | Compute layer varies |
| **Network** | libvirt NAT | VNet/Subnet | VPC/Subnet | Provider-specific | CIDR ranges configurable |
| **Kubernetes** | K3s | K3s | K3s | **Identical** | Same distribution, same version |
| **GitOps** | Argo CD | Argo CD | Argo CD | **Identical** | Same manifests, same repo |
| **EJBCA** | Container | Container | Container | **Identical** | Same image, same config |
| **PostgreSQL** | Container | Container | Container | **Identical** | Bitnami chart everywhere |
| **OpenBao** | Container | Container | Container | **Identical** | Same Helm chart, same values |
| **SPIRE** | Container | Container | Container | **Identical** | Same manifests, trust domain configurable |
| **RabbitMQ** | Container | Container | Container | **Identical** | Same image, same config |
| **cert-api** | Container | Container | Container | **Identical** | Custom app, same code |
| **cert-worker** | Container | Container | Container | **Identical** | Custom app, same code |
| **ca-service** | Container | Container | Container | **Identical** | Custom app, same code |
| **cert-manager** | Container | Container | Container | **Identical** | Same Helm chart |
| **Prometheus** | Container | Container | Container | **Identical** | kube-prometheus-stack |
| **Grafana** | Container | Container | Container | **Identical** | Same chart, same dashboards |
| **Registry** | Container | Container | Container | **Identical** | Harbor or registry:2 |

---

## Environment-Specific Differences

### Trust Domain

| Environment | Trust Domain | SPIFFE ID Example |
|-------------|--------------|-------------------|
| Homelab | `homelab.local` | `spiffe://homelab.local/ns/pki/sa/cert-worker` |
| Azure | `pki-azure.local` | `spiffe://pki-azure.local/ns/pki/sa/cert-worker` |
| AWS | `pki-aws.local` | `spiffe://pki-aws.local/ns/pki/sa/cert-worker` |

### Storage Classes

| Environment | Storage Class | Provisioner | Notes |
|-------------|---------------|-------------|-------|
| Homelab | `local-path` | rancher.io/local-path | K3s default |
| Azure | `managed-csi` | disk.csi.azure.com | Azure Disk CSI |
| AWS | `gp2` / `gp3` | ebs.csi.aws.com | EBS CSI driver |

### Load Balancer

| Environment | Type | Implementation |
|-------------|------|----------------|
| Homelab | LoadBalancer | K3s ServiceLB (klipper-lb) |
| Azure | LoadBalancer | Azure Load Balancer (VM-based) |
| AWS | LoadBalancer | AWS NLB or Classic LB |

### Ingress

| Environment | Controller | Notes |
|-------------|------------|-------|
| Homelab | None (NodePort) | Traefik disabled |
| Azure | None (NodePort) | Same pattern for consistency |
| AWS | None (NodePort) | Same pattern for consistency |

---

## Resource Requirements (Per Environment)

### Minimum VM/EC2 Specifications

| Environment | vCPU | RAM | Disk | Notes |
|-------------|------|-----|------|-------|
| Homelab | 4 | 11 GB | 36 GB | Current k8s01 VM |
| Azure | 2-4 | 8-16 GB | 64 GB | Standard_B2s or B4ms |
| AWS | 2 | 4-8 GB | 32 GB | t3.micro (free tier) or t3.small |

### Container Resource Requests/Limits

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| EJBCA | 500m | 2000m | 1Gi | 2Gi |
| PostgreSQL | 250m | 1000m | 512Mi | 1Gi |
| OpenBao | 100m | 500m | 256Mi | 512Mi |
| SPIRE Server | 100m | 500m | 128Mi | 256Mi |
| SPIRE Agent | 100m | 500m | 128Mi | 256Mi |
| RabbitMQ | 200m | 1000m | 512Mi | 1Gi |
| cert-api | 100m | 500m | 128Mi | 256Mi |
| cert-worker | 100m | 500m | 128Mi | 256Mi |
| ca-service | 100m | 500m | 128Mi | 256Mi |
| cert-manager | 50m | 500m | 128Mi | 256Mi |
| Prometheus | 500m | 2000m | 2Gi | 4Gi |
| Grafana | 100m | 500m | 128Mi | 256Mi |

---

## Network Architecture

### Kubernetes Network

| Environment | Pod CIDR | Service CIDR | Cluster DNS |
|-------------|----------|--------------|-------------|
| Homelab | 10.42.0.0/24 | 10.43.0.0/16 | 10.43.0.10 |
| Azure | 10.42.0.0/16 | 10.43.0.0/16 | 10.43.0.10 |
| AWS | 10.42.0.0/16 | 10.43.0.0/16 | 10.43.0.10 |

### Service Ports

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| EJBCA Admin | 443 | HTTPS | Web UI, RA, VA |
| EJBCA Public | 80 | HTTP | CRL, OCSP, EST |
| PostgreSQL | 5432 | TCP | Database |
| OpenBao | 8200 | HTTPS | API, UI |
| OpenBao Raft | 8201 | HTTPS | Internal clustering |
| SPIRE Server | 8081 | TCP | gRPC |
| SPIRE Agent | (socket) | Unix | Local workload attestation |
| RabbitMQ AMQP | 5672 | TCP | Message queue |
| RabbitMQ Mgmt | 15672 | HTTP | Management UI |
| cert-api | 8000 | HTTP | REST API |
| ca-service | 8000 | HTTP | CA abstraction API |
| Prometheus | 9090 | HTTP | Metrics |
| Grafana | 3000 | HTTP | Dashboards |
| Registry | 5000 | HTTP | Container images |

---

## Data Persistence

### Persistent Volumes

| Component | Size | Access Mode | Backup Strategy |
|-----------|------|-------------|-----------------|
| PostgreSQL (EJBCA) | 10Gi | RWO | Daily snapshot |
| PostgreSQL (PKI) | 5Gi | RWO | Daily snapshot |
| OpenBao Raft | 5Gi | RWO | Automated backup to S3/Azure Blob |
| SPIRE Server | 1Gi | RWO | Recreatable (re-attest workloads) |
| EJBCA Config | 1Gi | RWO | Git-managed + backup |
| Prometheus | 20Gi | RWO | Retention-based |
| Registry | 50Gi | RWO | Rebuildable from CI |

### Backup Priorities

1. **Critical**: EJBCA PostgreSQL (CA state, certificates)
2. **Critical**: OpenBao data (secrets, PKI mount)
3. **Important**: SPIRE server data (registration entries)
4. **Important**: PKI PostgreSQL (inventory, audit)
5. **Nice-to-have**: Prometheus metrics

---

## Security Boundaries

### Network Policies

All namespaces implement:
- **Default deny** ingress/egress
- **Explicit allow** for required communications
- **Namespace-level** isolation

### mTLS Requirements

| Communication | mTLS Required | SPIFFE ID | Notes |
|---------------|---------------|-----------|-------|
| cert-api ↔ RabbitMQ | Yes | `spiffe://.../sa/cert-api` | Client cert auth |
| cert-worker ↔ RabbitMQ | Yes | `spiffe://.../sa/cert-worker` | Client cert auth |
| cert-api ↔ OpenBao | Yes | `spiffe://.../sa/cert-api` | SPIFFE auth method |
| cert-worker ↔ OpenBao | Yes | `spiffe://.../sa/cert-worker` | SPIFFE auth method |
| ca-service ↔ EJBCA | Yes | `spiffe://.../sa/ca-service` | Client cert auth |
| Workload ↔ SPIRE Agent | Yes | N/A (Unix socket) | Local only |

### Secret Management

| Secret Type | Stored In | Rotation | Notes |
|-------------|-----------|----------|-------|
| CA private keys | OpenBao PKI mount | Manual ceremony | Never in K8s secrets |
| Database passwords | OpenBao KV | Automated | Dynamic credentials preferred |
| API tokens | OpenBao KV | Automated | Short-lived |
| TLS certificates | cert-manager / SPIRE | Automatic | 90-day default |
| Registry credentials | OpenBao KV | Manual | Pull secrets |

---

## Operational Considerations

### Scaling

| Component | Scaling Strategy | Horizontal Pod Autoscaler |
|-----------|------------------|---------------------------|
| cert-api | Replicas: 2-4 | CPU > 70% |
| cert-worker | Replicas: 1-3 | Queue depth > 100 |
| ca-service | Replicas: 2-4 | CPU > 70% |
| EJBCA | Single instance | Manual (stateful) |
| PostgreSQL | Single instance | Manual (read replicas future) |
| OpenBao | Single instance | Manual (HA mode future) |
| RabbitMQ | Replicas: 1-3 | Manual (queue mirroring) |

### Health Checks

| Component | Liveness | Readiness | Startup |
|-----------|----------|-----------|---------|
| cert-api | HTTP /health | HTTP /ready | 30s delay |
| cert-worker | Process | Queue connectivity | 10s delay |
| ca-service | HTTP /health | HTTP /ready | 30s delay |
| EJBCA | HTTP /ejbca/health | HTTP /ejbca/health | 120s delay |
| PostgreSQL | pg_isready | pg_isready | 10s delay |
| OpenBao | HTTP /v1/sys/health | HTTP /v1/sys/health | 30s delay |
| RabbitMQ | rabbitmq-diagnostics | HTTP /api/health | 30s delay |

---

## Cloud-Specific Integration Points

### Azure Integration (Documented, Not Deployed)

| Integration | Purpose | Status |
|-------------|---------|--------|
| Azure Managed Identity | VM identity for cloud resource access | Documented |
| Azure Key Vault | HSM-backed key storage (future) | Documented |
| Azure Monitor | Metrics and logging (future) | Documented |
| Azure Blob Storage | Backup target (future) | Documented |

### AWS Integration (Documented, Not Deployed)

| Integration | Purpose | Status |
|-------------|---------|--------|
| IAM Instance Profile | EC2 identity for cloud resource access | Documented |
| AWS KMS | HSM-backed key storage (future) | Documented |
| CloudWatch | Metrics and logging (future) | Documented |
| S3 | Backup target (future) | Documented |

---

## Future Enhancements

1. **Multi-node K3s**: HA control plane and worker nodes
2. **PostgreSQL HA**: Patroni or cloud-managed PostgreSQL
3. **OpenBao HA**: Raft cluster with auto-unseal (cloud KMS)
4. **External HSM**: AWS CloudHSM or Azure Dedicated HSM for CA keys
5. **Cross-cluster SPIFFE**: Federation between trust domains
6. **Certificate Transparency**: CT log submission for issued certificates
7. **Automated Renewal**: cert-manager integration with EJBCA issuer
8. **Policy Engine**: OPA/Gatekeeper for certificate policy enforcement
9. **Disaster Recovery**: Cross-region replication, automated failover
10. **CI/CD Integration**: GitHub Actions for image builds and GitOps validation

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-02 | PKI Platform Engineer | Initial cloud-neutral architecture |
