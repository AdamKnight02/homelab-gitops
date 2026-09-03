# Cloud-Neutral Reference Architecture

> **Purpose**: Define the logical architecture that is portable across homelab, Azure, and AWS.

## Design Philosophy

The PKI platform is designed to be **cloud-neutral** at the workload layer. The only provider-specific components are:

1. **Infrastructure layer** (VM, network, IAM) — Terraform handles this
2. **Bootstrap layer** (cloud-init) — provider-specific metadata/APIs
3. **Identity integration** — SPIFFE complements cloud-native identity

All platform components run identically in K3s on any Linux VM.

## Logical Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Client / Application                    │
└──────────────────────────┬──────────────────────────────────┘
                           │ mTLS
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Certificate API (cert-api)                 │
│              REST/gRPC → AuthN/AuthZ → Policy               │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      RabbitMQ (AMQP)                         │
│              Async queue for certificate jobs                │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Certificate Worker (cert-worker)            │
│              Processes queue → calls CA abstraction          │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              CA Abstraction Layer (ca-service)               │
│              Unified interface to multiple CAs               │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      EJBCA (PKI Core)                        │
│              Root CA / Issuing CA / OCSP / CRL               │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL (Database)                     │
│              CA data, certificate inventory, audit           │
└─────────────────────────────────────────────────────────────┘
```

## Supporting Infrastructure

```
┌─────────────────────────────────────────────────────────────┐
│                    SPIRE / SPIFFE                            │
│  Workload identity → SVIDs → mTLS between services          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      OpenBao (Secrets)                       │
│  Secret storage, PKI engine, KV, dynamic credentials        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  cert-manager (Kubernetes)                   │
│  Automatic TLS for ingress and internal services            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Prometheus + Grafana (Observability)            │
│  Metrics, alerting, dashboards                              │
└─────────────────────────────────────────────────────────────┘
```

## Certificate Lifecycle

```
Request → Validate → Queue → Process → Issue → Store → Inventory → Audit
   │         │        │         │        │       │         │         │
   ▼         ▼        ▼         ▼        ▼       ▼         ▼         ▼
 cert-api  AuthN   RabbitMQ  Worker   EJBCA  K8s Secret  DB      OpenBao
           AuthZ                      CA     / OpenBao           Audit Log
```

## Portability Matrix

| Component | Homelab | Azure | AWS | Notes |
|-----------|---------|-------|-----|-------|
| **Infrastructure** | libvirt/KVM | Terraform + VM | Terraform + EC2 | Provider-specific |
| **Network** | LAN bridge | VNet + NSG | VPC + SG | Different names, same concepts |
| **Compute** | Red Hat VM | Ubuntu VM | Amazon Linux | All run K3s |
| **Kubernetes** | K3s | K3s | K3s | **Identical** |
| **GitOps** | Argo CD | Argo CD | Argo CD | **Identical** |
| **PKI Core** | EJBCA | EJBCA | EJBCA | **Identical** (containerized) |
| **Database** | PostgreSQL | PostgreSQL | PostgreSQL | **Identical** (containerized) |
| **Secrets** | OpenBao | OpenBao | OpenBao | **Identical** (containerized) |
| **Identity** | SPIRE | SPIRE | SPIRE | **Identical** (containerized) |
| **Queue** | RabbitMQ | RabbitMQ | RabbitMQ | **Identical** (containerized) |
| **API** | cert-api | cert-api | cert-api | **Identical** (containerized) |
| **Worker** | cert-worker | cert-worker | cert-worker | **Identical** (containerized) |
| **Monitoring** | Prometheus/Grafana | Prometheus/Grafana | Prometheus/Grafana | **Identical** |
| **Registry** | Docker Registry | Docker Registry | Docker Registry | **Identical** |

## Cloud-Native Integration Points

While the core platform is cloud-neutral, these integration points are provider-specific:

### Azure
- **Managed Identity**: Can authenticate to Azure Key Vault (if used alongside OpenBao)
- **Azure AD**: Can be identity provider for Argo CD SSO
- **Azure Monitor**: Can collect metrics from Prometheus
- **Azure DNS**: Can be used for ACME DNS-01 challenges

### AWS
- **IAM Roles**: Instance profile provides AWS API access
- **AWS Secrets Manager**: Can be used alongside OpenBao
- **CloudWatch**: Can collect metrics from Prometheus
- **Route 53**: Can be used for ACME DNS-01 challenges

### Homelab
- **Local DNS**: Internal DNS resolution
- **Local CA**: EJBCA issues all certificates
- **No cloud IAM**: SPIFFE is the primary identity system

## Design Decisions

### Why K3s instead of managed Kubernetes?

| Factor | K3s | AKS/EKS |
|--------|-----|---------|
| Cost | Free | $72+/mo |
| Complexity | Low | High |
| Learning | Full control | Abstracted |
| Portability | Runs anywhere | Provider-specific |
| Similarity to homelab | Identical | Different |

### Why VM instead of container platforms?

| Factor | VM + K3s | ACI/ECS/Fargate |
|--------|----------|-----------------|
| Cost | Low | Higher |
| Stateful workloads | Easy | Hard |
| EJBCA requirements | Full OS access | Limited |
| Learning | Complete stack | Abstracted |

### Why OpenBao instead of cloud-native secrets?

| Factor | OpenBao | Azure Key Vault / AWS Secrets Manager |
|--------|---------|--------------------------------------|
| Portability | Runs anywhere | Provider-specific |
| PKI engine | Built-in | Limited or absent |
| SPIFFE integration | Native | Requires bridging |
| Cost | Free | Per-operation |
| Learning | Complete | Abstracted |
