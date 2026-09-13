# Containerization Model

## Overview

This document defines the **containerization model** for the Machine Identity Platform, specifying which components run as containers versus virtual machines, and how that placement changes across service tiers.

**Core Principle:** The platform is **container-first**. All application workloads run as containers on Kubernetes. VMs are used only for infrastructure nodes (control plane, workers) and for specialized workloads that cannot be containerized (e.g., HSM clients, legacy systems).

---

## Container-First Philosophy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONTAINER-FIRST ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         VIRTUAL MACHINES                             │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │    │
│  │  │  Control    │  │   Worker    │  │   Worker    │                 │    │
│  │  │   Plane     │  │   Node 1    │  │   Node 2    │                 │    │
│  │  │  (K3s/      │  │  (K3s/      │  │  (K3s/      │                 │    │
│  │  │   K8s)      │  │   K8s)      │  │   K8s)      │                 │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                 │    │
│  │         │                │                │                        │    │
│  │         └────────────────┴────────────────┘                        │    │
│  │                          │                                         │    │
│  │                          ▼                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────┐  │    │
│  │  │                    CONTAINER RUNTIME                         │  │    │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐ │  │    │
│  │  │  │ cert-api│ │cert-work│ │ca-service│ │  EJBCA  │ │OpenBao│ │  │    │
│  │  │  │ (2+)    │ │  (2+)   │ │  (2+)   │ │  (1+)   │ │ (3+)  │ │  │    │
│  │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────┘ │  │    │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐ │  │    │
│  │  │  │PostgreSQL│ │RabbitMQ │ │  SPIRE  │ │Prometheus│ │Grafana│ │  │    │
│  │  │  │  (1+)   │ │  (3+)   │ │  (1+)   │ │  (2+)   │ │ (2+)  │ │  │    │
│  │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────┘ │  │    │
│  │  └─────────────────────────────────────────────────────────────┘  │    │
│  │                                                                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    SPECIALIZED WORKLOADS (VM-BASED)                  │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │    │
│  │  │   HSM       │  │   Legacy    │  │   Backup    │                 │    │
│  │  │   Client    │  │   System    │  │   Server    │                 │    │
│  │  │   (PKCS#11) │  │   Adapter   │  │   (Bacula/  │                 │    │
│  │  │             │  │             │  │   Restic)   │                 │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │    │
│  │                                                                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Classification

### Always Containerized

These components are **always deployed as containers** regardless of tier:

| Component | Container Image | Rationale |
|-----------|-----------------|-----------|
| **cert-api** | `registry/cert-api:{version}` | Stateless REST API, horizontally scalable |
| **cert-worker** | `registry/cert-worker:{version}` | Stateless batch consumer, horizontally scalable |
| **ca-service** | `registry/ca-service:{version}` | Stateless CA abstraction, horizontally scalable |
| **EJBCA** | `keyfactor/ejbca-ce:{version}` | CA application, containerized by vendor |
| **PostgreSQL** | `bitnami/postgresql:{version}` | Database, containerized via Helm chart |
| **OpenBao** | `openbao:{version}` | Secrets management, containerized via Helm chart |
| **SPIRE Server** | `ghcr.io/spiffe/spire-server:{version}` | Identity server, containerized |
| **SPIRE Agent** | `ghcr.io/spiffe/spire-agent:{version}` | Identity agent, DaemonSet |
| **RabbitMQ** | `rabbitmq:{version}-management` | Message queue, containerized |
| **cert-manager** | `quay.io/jetstack/cert-manager-controller:{version}` | Certificate automation, containerized |
| **Prometheus** | `prom/prometheus:{version}` | Metrics, containerized via Helm chart |
| **Grafana** | `grafana/grafana:{version}` | Dashboards, containerized via Helm chart |
| **Alertmanager** | `prom/alertmanager:{version}` | Alerting, containerized via Helm chart |
| **Registry** | `registry:{version}` | Container registry, containerized |
| **Nginx (EJBCA sidecar)** | `nginx:{version}` | TLS termination, containerized |

### Conditionally Containerized

These components may run as containers or VMs depending on tier and requirements:

| Component | Container (Default) | VM (Alternative) | When to Use VM |
|-----------|---------------------|------------------|----------------|
| **PostgreSQL (HA)** | Bitnami HA chart | Patroni on VMs | ENTERPRISE with strict latency requirements |
| **Backup Server** | Restic container | Bacula on VM | ENTERPRISE with existing backup infrastructure |
| **Log Aggregator** | Fluent Bit container | rsyslog on VM | ENTERPRISE with existing syslog infrastructure |
| **Monitoring (long-term)** | Thanos/Cortex containers | Dedicated monitoring VM | ENTERPRISE with 1+ year retention |

### Never Containerized (VM-Based)

These components run on dedicated VMs or bare metal:

| Component | Rationale | Tier |
|-----------|-----------|------|
| **HSM Client** | PKCS#11 requires direct hardware access | ENTERPRISE |
| **Legacy System Adapter** | Cannot be containerized due to OS dependencies | All (if needed) |
| **Air-Gapped Root CA** | Offline operation, no network stack | All (security requirement) |
| **Bastion Host** | SSH access, minimal attack surface | STANDARD, ENTERPRISE |

---

## Service Placement Matrix

### ECONOMY Tier

| Component | Placement | Replicas | Node Assignment | Notes |
|-----------|-----------|----------|-----------------|-------|
| **K3s Control Plane** | VM | 1 | node-1 | Single node |
| **K3s Worker** | VM | 0 (co-located) | node-1 | Same as control plane |
| **cert-api** | Container | 1 | node-1 | Single replica |
| **cert-worker** | Container | 1 | node-1 | Single replica |
| **ca-service** | Container | 1 | node-1 | Single replica |
| **EJBCA** | Container | 1 | node-1 | Single replica |
| **PostgreSQL** | Container | 1 | node-1 | Single container |
| **OpenBao** | Container | 1 | node-1 | Standalone |
| **SPIRE Server** | Container | 1 | node-1 | Single server |
| **SPIRE Agent** | Container | 1 | node-1 | DaemonSet (1 node) |
| **RabbitMQ** | Container | 1 | node-1 | Single node |
| **cert-manager** | Container | 1 | node-1 | Single replica |
| **Prometheus** | Container | 1 | node-1 | Single replica |
| **Grafana** | Container | 1 | node-1 | Single replica |
| **Registry** | Container | 1 | node-1 | Single replica |
| **HSM Client** | N/A | — | — | Not used |
| **Bastion** | N/A | — | — | Not used |

**Total VMs:** 1
**Total Containers:** ~15

---

### STANDARD Tier

| Component | Placement | Replicas | Node Assignment | Notes |
|-----------|-----------|----------|-----------------|-------|
| **K3s Control Plane** | VM | 1 | node-1 | Server |
| **K3s Worker** | VM | 2 | node-2, node-3 | Agents |
| **cert-api** | Container | 2 | node-2, node-3 | Anti-affinity |
| **cert-worker** | Container | 2 | node-2, node-3 | Anti-affinity |
| **ca-service** | Container | 2 | node-2, node-3 | Anti-affinity |
| **EJBCA** | Container | 1 (active) + 1 (standby) | node-2 (active), node-3 (standby) | Pod anti-affinity |
| **PostgreSQL** | Container | 1 (primary) + 1 (replica) | node-2 (primary), node-3 (replica) | Streaming replication |
| **OpenBao** | Container | 3 | node-1, node-2, node-3 | Raft cluster |
| **SPIRE Server** | Container | 1 | node-1 | With standby on node-2 |
| **SPIRE Agent** | Container | 3 | node-1, node-2, node-3 | DaemonSet |
| **RabbitMQ** | Container | 3 | node-1, node-2, node-3 | Cluster |
| **cert-manager** | Container | 1 | node-2 | Single replica |
| **Prometheus** | Container | 2 | node-2, node-3 | Federated |
| **Grafana** | Container | 2 | node-2, node-3 | Active-active |
| **Registry** | Container | 1 | node-2 | Single replica |
| **HSM Client** | N/A | — | — | Optional |
| **Bastion** | VM | 1 | bastion-1 | SSH access |

**Total VMs:** 4 (3 K3s + 1 bastion)
**Total Containers:** ~25

---

### ENTERPRISE Tier

| Component | Placement | Replicas | Node Assignment | Notes |
|-----------|-----------|----------|-----------------|-------|
| **K3s Control Plane** | VM | 3 | cp-1, cp-2, cp-3 | HA control plane |
| **K3s Worker** | VM | 3+ | worker-1, worker-2, worker-3+ | Multi-zone |
| **cert-api** | Container | 3+ | worker-* | HPA, topology spread |
| **cert-worker** | Container | 3+ | worker-* | Queue autoscaling |
| **ca-service** | Container | 3+ | worker-* | HPA, topology spread |
| **EJBCA** | Container | 2+ (active-active) | worker-* | Shared HA database |
| **PostgreSQL** | Container or VM | 3 (Patroni) or managed | db-1, db-2, db-3 or cloud | HA cluster |
| **OpenBao** | Container | 5 | worker-* | Raft cluster + auto-unseal |
| **SPIRE Server** | Container | 3 | worker-* | Clustered, upstream CA |
| **SPIRE Agent** | Container | 6+ | all nodes | DaemonSet |
| **RabbitMQ** | Container | 3 | worker-* | Cluster, quorum queues |
| **cert-manager** | Container | 2 | worker-* | Active-active |
| **Prometheus** | Container | 3+ | worker-* | Thanos/Cortex |
| **Grafana** | Container | 3+ | worker-* | Active-active |
| **Alertmanager** | Container | 3 | worker-* | Clustered |
| **Registry** | Container | 2 | worker-* | Active-active |
| **HSM Client** | VM | 2 | hsm-1, hsm-2 | PKCS#11, failover |
| **Bastion** | VM | 2 | bastion-1, bastion-2 | HA bastion |
| **Backup Server** | VM | 1 | backup-1 | Dedicated backup |

**Total VMs:** 10+ (3 CP + 3+ workers + 2 HSM + 2 bastion + 1 backup)
**Total Containers:** ~40+

---

## Container Runtime Requirements

### Minimum Requirements (All Tiers)

| Requirement | Specification |
|-------------|---------------|
| **Container Runtime** | containerd 1.7+ or CRI-O 1.28+ |
| **Kubernetes** | v1.28+ (K3s v1.28+ for K3s deployments) |
| **CNI** | Flannel, Calico, or Cilium |
| **CSI** | Local-path (ECONOMY), Longhorn/Ceph (STANDARD), Cloud CSI (ENTERPRISE) |
| **Ingress** | None (ECONOMY), Traefik/NGINX (STANDARD), Cloud LB + Ingress (ENTERPRISE) |

### Image Requirements

| Requirement | Specification |
|-------------|---------------|
| **Registry** | OCI-compliant registry |
| **Image Format** | OCI or Docker image format |
| **Architecture** | linux/amd64 (primary), linux/arm64 (optional) |
| **Base Images** | distroless or alpine (preferred), debian slim (acceptable) |
| **Security** | Non-root user, read-only root filesystem, no privileged mode |

---

## Resource Profiles

### ECONOMY Resource Profile

```yaml
# Example: cert-api Deployment (ECONOMY)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-api
  namespace: pki
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: api
        image: registry/cert-api:v1.0.0
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
```

### STANDARD Resource Profile

```yaml
# Example: cert-api Deployment (STANDARD)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-api
  namespace: pki
spec:
  replicas: 2
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - cert-api
            topologyKey: kubernetes.io/hostname
      containers:
      - name: api
        image: registry/cert-api:v1.0.0
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 512Mi
```

### ENTERPRISE Resource Profile

```yaml
# Example: cert-api Deployment (ENTERPRISE)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-api
  namespace: pki
spec:
  replicas: 3
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - cert-api
            topologyKey: kubernetes.io/hostname
        topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: cert-api
      containers:
      - name: api
        image: registry/cert-api:v1.0.0
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 2000m
            memory: 1Gi
---
# HPA for ENTERPRISE
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cert-api
  namespace: pki
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cert-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## Storage Classes by Tier

| Tier | Storage Class | Provisioner | Reclaim Policy | Volume Binding |
|------|---------------|-------------|----------------|----------------|
| **ECONOMY** | `local-path` | rancher.io/local-path | Delete | WaitForFirstConsumer |
| **STANDARD** | `longhorn` or `ceph-rbd` | driver.longhorn.io or rbd.csi.ceph.com | Retain | Immediate |
| **ENTERPRISE** | `managed-csi` or `ebs-csi` | disk.csi.azure.com or ebs.csi.aws.com | Retain | WaitForFirstConsumer |

---

## Networking Model

### ECONOMY

```
┌─────────────┐
│   Node 1    │
│  (K3s all)  │
│             │
│  Pod CIDR:  │
│ 10.42.0.0/24│
│             │
│  Svc CIDR:  │
│ 10.43.0.0/16│
│             │
│  NodePort:  │
│ 30000-32767 │
└─────────────┘
```

### STANDARD

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Node 1    │     │   Node 2    │     │   Node 3    │
│  (Control)  │────►│  (Worker)   │────►│  (Worker)   │
│             │     │             │     │             │
│  Pod CIDR:  │     │  Pod CIDR:  │     │  Pod CIDR:  │
│ 10.42.0.0/24│     │ 10.42.1.0/24│     │ 10.42.2.0/24│
│             │     │             │     │             │
│  Svc CIDR:  │     │  Svc CIDR:  │     │  Svc CIDR:  │
│ 10.43.0.0/16│     │ 10.43.0.0/16│     │ 10.43.0.0/16│
│             │     │             │     │             │
│  LoadBalancer│    │             │     │             │
│  (external) │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
```

### ENTERPRISE

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     CP 1    │     │     CP 2    │     │     CP 3    │
│  (Control)  │────►│  (Control)  │────►│  (Control)  │
│   Zone A    │     │   Zone B    │     │   Zone C    │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
       ┌───────────────────┼───────────────────┐
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Worker 1   │     │  Worker 2   │     │  Worker 3   │
│   Zone A    │     │   Zone B    │     │   Zone C    │
│             │     │             │     │             │
│  Pod CIDR:  │     │  Pod CIDR:  │     │  Pod CIDR:  │
│ 10.42.0.0/24│     │ 10.42.1.0/24│     │ 10.42.2.0/24│
│             │     │             │     │             │
│  Cloud LB   │     │  Cloud LB   │     │  Cloud LB   │
│  (anycast)  │     │  (anycast)  │     │  (anycast)  │
└─────────────┘     └─────────────┘     └─────────────┘
```

---

## Security Model

### Pod Security Standards

| Tier | Pod Security Standard | Enforcement |
|------|----------------------|-------------|
| **ECONOMY** | Baseline | Warn |
| **STANDARD** | Restricted | Enforce |
| **ENTERPRISE** | Restricted + custom policies | Enforce + audit |

### Container Security Context

```yaml
# Standard security context for all containers
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  seccompProfile:
    type: RuntimeDefault
```

### Network Policies

All tiers use the same network policy structure:

```yaml
# Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: pki
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow specific communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cert-api-allow
  namespace: pki
spec:
  podSelector:
    matchLabels:
      app: cert-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: pki
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: rabbitmq
    ports:
    - protocol: TCP
      port: 5672
  - to:
    - namespaceSelector:
        matchLabels:
          name: openbao
    ports:
    - protocol: TCP
      port: 8200
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Platform Architect | Initial containerization model |
