# Service Tier Architecture

## Overview

This document defines the **provider-neutral service tier architecture** for the Machine Identity Platform. Tiers are **intent declarations**, not cloud SKUs. A customer says `service_tier: standard`, and the platform translates that into the appropriate infrastructure, topology, and resource allocations for whichever provider is in use.

**Core Principle:** Tiers describe *what* the customer needs (availability, scale, compliance), not *how* to build it (VM sizes, instance types, disk IOPS).

---

## Tier Definitions

### ECONOMY

**Intent:** Minimal viable PKI platform for development, testing, and small-scale use.

| Aspect | Specification |
|--------|---------------|
| **Availability Target** | 99.0% (single node, planned downtime acceptable) |
| **Node Count** | 1 |
| **HA Model** | None — single point of failure |
| **Use Case** | Dev/test, proof-of-concept, homelab |
| **Cost Sensitivity** | Maximum — minimize all spend |
| **Compliance** | None required |
| **Backup** | Optional, best-effort |
| **Support Model** | Self-service |

**Infrastructure Profile:**
- Single VM or bare-metal node
- K3s single-node cluster
- All components co-located on one node
- Local storage only
- No load balancer (NodePort or hostNetwork)
- No ingress controller (optional)

**Component Placement:**
- All services containerized on single node
- PostgreSQL: single container, local-path storage
- OpenBao: standalone mode, raft storage
- SPIRE: single server, single agent
- EJBCA: single replica
- RabbitMQ: single replica, no clustering
- cert-api: 1 replica
- cert-worker: 1 replica
- ca-service: 1 replica

---

### STANDARD

**Intent:** Production-ready PKI platform with high availability for critical services.

| Aspect | Specification |
|--------|---------------|
| **Availability Target** | 99.9% (multi-node, rolling updates supported) |
| **Node Count** | 3 (minimum) |
| **HA Model** | Active-active for stateless, active-passive for stateful |
| **Use Case** | Production, small-to-medium enterprise |
| **Cost Sensitivity** | Moderate — balance cost and reliability |
| **Compliance** | Basic audit logging, encryption at rest |
| **Backup** | Automated daily backups, 30-day retention |
| **Support Model** | Business hours support |

**Infrastructure Profile:**
- 3+ VMs across availability zones (or failure domains)
- K3s multi-node cluster (1 server, 2+ agents) or managed K8s
- Distributed storage (Longhorn, Ceph, or cloud CSI)
- Load balancer for control plane and ingress
- Ingress controller (Traefik, NGINX, or cloud LB)

**Component Placement:**
- Stateless services: 2+ replicas, anti-affinity across nodes
- Stateful services: 1 active + 1 standby (or clustered where supported)
- PostgreSQL: primary + standby replica (streaming replication)
- OpenBao: 3-node raft cluster (HA mode)
- SPIRE: 1 server (with standby), agents on all nodes
- EJBCA: 1 active + 1 standby (shared database)
- RabbitMQ: 3-node cluster with quorum queues
- cert-api: 2+ replicas
- cert-worker: 2+ replicas
- ca-service: 2+ replicas

---

### ENTERPRISE

**Intent:** Mission-critical PKI platform with maximum availability, compliance, and scale.

| Aspect | Specification |
|--------|---------------|
| **Availability Target** | 99.95%+ (multi-zone, automated failover) |
| **Node Count** | 6+ (3 control plane, 3+ workers) |
| **HA Model** | Active-active everywhere, automated failover |
| **Use Case** | Enterprise production, regulated industries |
| **Cost Sensitivity** | Low — reliability and compliance first |
| **Compliance** | Full audit trail, FIPS 140-2, SOC 2, PCI-DSS |
| **Backup** | Continuous backup, cross-region replication, 1-year retention |
| **Support Model** | 24/7 support, dedicated SRE |

**Infrastructure Profile:**
- 6+ VMs across 3 availability zones
- Managed Kubernetes (EKS, AKS, GKE) or hardened K3s cluster
- Cloud-native distributed storage (EBS, Azure Disk, PD with regional replication)
- Cloud load balancer with health checks and failover
- Ingress controller with WAF and DDoS protection
- Private endpoints for all data services

**Component Placement:**
- All stateless services: 3+ replicas, pod anti-affinity, topology spread
- Stateful services: clustered with automated failover
- PostgreSQL: 3-node Patroni cluster or cloud-managed HA (RDS, Azure Database)
- OpenBao: 5-node raft cluster with auto-unseal (cloud KMS)
- SPIRE: 3-node SPIRE server cluster (upstream CA), agents on all nodes
- EJBCA: 2+ active nodes behind LB (shared HA database)
- RabbitMQ: 3-node cluster with quorum queues, mirrored policies
- cert-api: 3+ replicas with HPA
- cert-worker: 3+ replicas with queue-based autoscaling
- ca-service: 3+ replicas with HPA
- External HSM integration for CA keys
- Dedicated monitoring stack with long-term retention

---

## Tier Comparison Matrix

| Capability | ECONOMY | STANDARD | ENTERPRISE |
|------------|---------|----------|------------|
| **Availability** | 99.0% | 99.9% | 99.95%+ |
| **Node Count** | 1 | 3 | 6+ |
| **Control Plane HA** | No | Yes (3 nodes) | Yes (3+ nodes, multi-zone) |
| **Data Replication** | None | Streaming replica | Synchronous multi-zone |
| **Backup Frequency** | Optional | Daily | Continuous |
| **Backup Retention** | 7 days | 30 days | 1 year |
| **Disaster Recovery** | Manual rebuild | Documented restore | Automated failover |
| **RTO** | 24 hours | 4 hours | 15 minutes |
| **RPO** | 24 hours | 1 hour | 5 minutes |
| **Audit Logging** | Basic | Full | Full + SIEM integration |
| **Encryption at Rest** | Optional | Yes | Yes (FIPS 140-2) |
| **Encryption in Transit** | TLS 1.2+ | TLS 1.2+ | TLS 1.3 only |
| **HSM Support** | No | Optional | Required |
| **Compliance** | None | Basic | SOC 2, PCI-DSS, HIPAA |
| **Autoscaling** | No | HPA (CPU) | HPA + VPA + cluster autoscaler |
| **Monitoring** | Basic metrics | Full stack + alerts | Full stack + APM + tracing |
| **Log Retention** | 7 days | 30 days | 1 year |
| **Network Policies** | Default deny | Default deny + explicit allow | Default deny + microsegmentation |
| **Secret Management** | OpenBao standalone | OpenBao HA | OpenBao HA + auto-unseal |
| **Certificate Renewal** | Manual | Automated | Automated + predictive |
| **OCSP/CRL** | Single responder | 2 responders | 3+ responders, global CDN |
| **Support** | Community | Business hours | 24/7 dedicated |

---

## What Changes Between Tiers

The following dimensions change based on tier selection. **Nothing else changes.** The same container images, the same application code, the same GitOps workflows, the same APIs.

### 1. Infrastructure Topology

| Dimension | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| Node count | 1 | 3 | 6+ |
| Control plane | Single | 3-node HA | 3+ node HA, multi-zone |
| Worker nodes | Co-located | 2+ dedicated | 3+ dedicated, multi-zone |
| Storage | Local-path | Distributed (Longhorn/Ceph) | Cloud CSI with replication |
| Networking | NodePort | LoadBalancer + Ingress | Cloud LB + Ingress + WAF |
| DNS | /etc/hosts or local DNS | Cloud DNS or external DNS | Global DNS with failover |

### 2. Component Replicas

| Component | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| cert-api | 1 | 2 | 3+ |
| cert-worker | 1 | 2 | 3+ |
| ca-service | 1 | 2 | 3+ |
| EJBCA | 1 | 1 (active) + 1 (standby) | 2+ (active-active) |
| PostgreSQL | 1 | 1 (primary) + 1 (replica) | 3 (Patroni) or managed HA |
| OpenBao | 1 (standalone) | 3 (raft cluster) | 5 (raft cluster) |
| SPIRE Server | 1 | 1 (with standby) | 3 (clustered) |
| SPIRE Agent | 1 (DaemonSet) | 3+ (DaemonSet) | 6+ (DaemonSet) |
| RabbitMQ | 1 | 3 (cluster) | 3 (cluster) |
| Prometheus | 1 | 2 (federated) | 3+ (Thanos/Cortex) |
| Grafana | 1 | 2 | 3+ |

### 3. Resource Allocations

| Component | ECONOMY (requests) | STANDARD (requests) | ENTERPRISE (requests) |
|-----------|-------------------|---------------------|----------------------|
| cert-api | 100m / 128Mi | 250m / 256Mi | 500m / 512Mi |
| cert-worker | 100m / 128Mi | 250m / 256Mi | 500m / 512Mi |
| ca-service | 100m / 128Mi | 250m / 256Mi | 500m / 512Mi |
| EJBCA | 500m / 1Gi | 1000m / 2Gi | 2000m / 4Gi |
| PostgreSQL | 250m / 512Mi | 500m / 1Gi | 1000m / 2Gi |
| OpenBao | 100m / 256Mi | 250m / 512Mi | 500m / 1Gi |
| SPIRE Server | 100m / 128Mi | 250m / 256Mi | 500m / 512Mi |
| RabbitMQ | 200m / 512Mi | 500m / 1Gi | 1000m / 2Gi |

### 4. Storage Configuration

| Component | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| PostgreSQL data | 10Gi local-path | 50Gi distributed | 100Gi+ cloud CSI, encrypted |
| OpenBao data | 5Gi local-path | 20Gi distributed | 50Gi+ cloud CSI, encrypted |
| OpenBao audit | 1Gi local-path | 5Gi distributed | 10Gi+ cloud CSI, encrypted |
| SPIRE data | 1Gi local-path | 5Gi distributed | 10Gi+ cloud CSI |
| Prometheus | 10Gi local-path | 50Gi distributed | 200Gi+ cloud CSI, long-term |
| Registry | 20Gi local-path | 100Gi distributed | 500Gi+ cloud CSI |

### 5. High Availability Configuration

| Component | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| PostgreSQL | Single container | Streaming replication | Patroni cluster / managed HA |
| OpenBao | Standalone raft | 3-node raft cluster | 5-node raft + auto-unseal |
| SPIRE | Single server | Server + standby | 3-node cluster, upstream CA |
| EJBCA | Single replica | Active + standby | Active-active, shared DB |
| RabbitMQ | Single node | 3-node cluster | 3-node cluster, quorum queues |
| cert-api | Single replica | 2 replicas, PDB | 3+ replicas, PDB, HPA |
| cert-worker | Single replica | 2 replicas, PDB | 3+ replicas, PDB, queue autoscaling |

### 6. Security Configuration

| Control | ECONOMY | STANDARD | ENTERPRISE |
|---------|---------|----------|------------|
| Network policies | Default deny | Default deny + explicit allow | Microsegmentation |
| Pod security | Baseline | Restricted | Restricted + seccomp + AppArmor |
| TLS version | 1.2+ | 1.2+ | 1.3 only |
| Cipher suites | Default | Strong | FIPS-approved |
| HSM | No | Optional | Required for CA keys |
| Audit logging | Basic | Full | Full + SIEM export |
| Vulnerability scanning | Manual | Weekly | Continuous |
| Penetration testing | No | Annual | Quarterly |

### 7. Observability Configuration

| Capability | ECONOMY | STANDARD | ENTERPRISE |
|------------|---------|----------|------------|
| Metrics retention | 7 days | 30 days | 1 year |
| Log retention | 7 days | 30 days | 1 year |
| Alerting | Basic | Full rules | Full rules + PagerDuty/OpsGenie |
| Dashboards | Basic | Full | Full + custom |
| Tracing | No | Optional | Yes (Jaeger/Tempo) |
| APM | No | Optional | Yes |
| SLO tracking | No | Yes | Yes + error budgets |

---

## What Does NOT Change Between Tiers

These elements are **identical across all tiers**:

| Element | Why It Doesn't Change |
|---------|----------------------|
| **Container images** | Same images, same versions, same registries |
| **Application code** | Same cert-api, cert-worker, ca-service code |
| **API contracts** | Same REST API, same message formats |
| **GitOps workflows** | Same Argo CD apps, same sync policies |
| **Kubernetes manifests** | Same Deployments, Services, ConfigMaps (replica counts patched) |
| **Helm charts** | Same charts, same values structure (tier-specific values files) |
| **Network policies** | Same rules, same selectors |
| **RBAC** | Same roles, same bindings |
| **Service accounts** | Same names, same permissions |
| **SPIFFE ID scheme** | Same `spiffe://{trust_domain}/ns/{namespace}/sa/{sa}` pattern |
| **Certificate profiles** | Same EJBCA profiles, same key usages |
| **Enrollment protocols** | Same EST, SCEP, ACME, CMP support |
| **Audit schema** | Same event types, same database schema |
| **Backup procedures** | Same scripts, same retention logic (frequency varies) |
| **Runbooks** | Same operational procedures |

---

## Tier Selection Guide

### Choose ECONOMY when:
- Development or testing environment
- Proof-of-concept or evaluation
- Budget is the primary constraint
- Downtime is acceptable
- No compliance requirements
- Single administrator

### Choose STANDARD when:
- Production workloads
- Business-critical certificates
- High availability required
- Basic compliance needs (audit logging)
- Small-to-medium team
- Predictable traffic patterns

### Choose ENTERPRISE when:
- Mission-critical PKI
- Regulated industry (finance, healthcare, government)
- Maximum availability required
- Strict compliance requirements (SOC 2, PCI-DSS, HIPAA)
- Large team with 24/7 operations
- High-volume certificate issuance
- Multi-region deployment needed

---

## Tier Upgrade Path

```
ECONOMY ──► STANDARD ──► ENTERPRISE
   │            │            │
   │            │            │
   ▼            ▼            ▼
Add nodes    Add HA      Add multi-zone
Add storage  Add LB      Add managed DB
Add backups  Add monitoring Add HSM
             Add autoscaling Add SIEM
                          Add compliance
```

**Upgrade Strategy:**
1. **ECONOMY → STANDARD**: Add nodes, enable distributed storage, configure LB, increase replicas
2. **STANDARD → ENTERPRISE**: Add zones, enable managed HA database, integrate HSM, add SIEM, enable compliance controls

**No re-architecture required.** The same GitOps repository, the same manifests, the same application code. Only the infrastructure layer and replica counts change.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Platform Architect | Initial service tier architecture |
