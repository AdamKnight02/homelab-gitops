# Local Architecture Inventory

> Generated: 2026-09-02
> Source: Direct inspection of K3s cluster via SSH (k8s01 VM)

## Environment Summary

| Component | Detail |
|-----------|--------|
| **Host** | frostnode (Fedora Linux 44 Workstation) |
| **K3s VM** | k8s01 (192.168.122.74, Red Hat Enterprise Linux 9.8) |
| **K3s Version** | v1.36.2+k3s1 |
| **Container Runtime** | containerd v2.3.2-k3s2 |
| **Node Resources** | 11GB RAM, single control-plane |
| **Node Status** | Ready, 11% CPU, 51% memory |

---

## Compute

### Nodes
- **k8s01** — Single control-plane node, Ready

### Namespaces (13 total)
| Namespace | Purpose | Status |
|-----------|---------|--------|
| argocd | GitOps controller | Active |
| cert-manager | TLS certificate automation | Active |
| default | Default namespace | Active |
| ejbca | EJBCA PKI + PostgreSQL | Active |
| kube-node-lease | K3s node leases | Active |
| kube-public | Public resources | Active |
| kube-system | K3s system components | Active |
| monitoring | Prometheus/Grafana stack | Active |
| openbao | Secrets management | Active |
| pki | Certificate services | Active |
| rabbitmq | Message queue | Active |
| registry | Container registry | Active |
| spire | Workload identity | Active |

### Deployments
| Namespace | Name | Replicas | Status |
|-----------|------|----------|--------|
| argocd | argocd-applicationset-controller | 1/1 | Running |
| argocd | argocd-dex-server | 1/1 | Running |
| argocd | argocd-notifications-controller | 1/1 | Running |
| argocd | argocd-redis | 1/1 | Running |
| argocd | argocd-repo-server | 1/1 | Running |
| argocd | argocd-server | 1/1 | Running |
| cert-manager | cert-manager | 1/1 | Running |
| cert-manager | cert-manager-cainjector | 1/1 | Running |
| cert-manager | cert-manager-webhook | 1/1 | Running |
| kube-system | coredns | 1/1 | Running |
| kube-system | local-path-provisioner | 1/1 | Running |
| kube-system | metrics-server | 1/1 | Running |
| monitoring | kube-prometheus-stack-grafana | 1/1 | Running |
| monitoring | kube-prometheus-stack-kube-state-metrics | 1/1 | Running |
| monitoring | kube-prometheus-stack-operator | 1/1 | Running |
| pki | ca-service | 2/2 | Running |
| pki | cert-api | 2/2 | Running |
| pki | cert-api-spire | 1/1 | Running |
| pki | cert-worker | 1/1 | Running |
| pki | pki-database | 1/1 | Running |
| registry | registry | 1/1 | Running |
| spire | spire-csi-spiffe-oidc-discovery-provider | 1/1 | Running |

### StatefulSets
| Namespace | Name | Replicas | Status |
|-----------|------|----------|--------|
| argocd | argocd-application-controller | 1/1 | Running |
| ejbca | ejbca-ejbca-ce | 1/1 | Running |
| ejbca | postgres-postgresql | 1/1 | Running |
| monitoring | alertmanager-kube-prometheus-stack-alertmanager | 1/1 | Running |
| monitoring | prometheus-kube-prometheus-stack-prometheus | 1/1 | Running |
| openbao | openbao | 1/1 | Running |
| rabbitmq | rabbitmq | 1/1 | Running |
| spire | spire-csi-server | 1/1 | Running |
| spire | spire-server | 1/1 | Running |

### DaemonSets
| Namespace | Name | Desired | Current | Ready |
|-----------|------|---------|---------|-------|
| kube-system | svclb-ejbca-ejbca-ce-nginx-13503e27 | 1 | 1 | 1 |
| monitoring | kube-prometheus-stack-prometheus-node-exporter | 1 | 1 | 1 |
| spire | spire-agent | 1 | 1 | 1 |
| spire | spire-csi-agent | 1 | 1 | 1 |
| spire | spire-csi-spiffe-csi-driver | 1 | 1 | 1 |

---

## PKI Components

### EJBCA
- **Namespace**: ejbca
- **Deployment**: ejbca-ejbca-ce (StatefulSet)
- **Database**: postgres-postgresql (StatefulSet)
- **Service**: ejbca-ejbca-ce-nginx (LoadBalancer @ 192.168.122.74)
- **Status**: Running, Healthy

### OpenBao
- **Namespace**: openbao
- **Deployment**: openbao (StatefulSet)
- **Services**:
  - openbao (ClusterIP: 8200, 8201)
  - openbao-internal (ClusterIP: 8200, 8201)
  - openbao-ui (ClusterIP: 8200)
  - openbao-ui-nodeport (NodePort: 30820)
- **Status**: Running, Healthy
- **PVCs**: audit (1Gi), data (5Gi)

### SPIRE
- **Namespace**: spire
- **Components**:
  - spire-server (StatefulSet)
  - spire-csi-server (StatefulSet)
  - spire-agent (DaemonSet)
  - spire-csi-agent (DaemonSet)
  - spire-csi-spiffe-csi-driver (DaemonSet)
  - spire-csi-spiffe-oidc-discovery-provider (Deployment)
- **Status**: Running, Healthy
- **PVCs**: spire-data-spire-csi-server-0 (1Gi), spire-data-spire-server-0 (1Gi)

### cert-manager
- **Namespace**: cert-manager
- **Components**: cert-manager, cainjector, webhook
- **Status**: Running, Healthy

---

## Platform Components

### Certificate Services (pki namespace)
| Component | Type | Replicas | Service | Port |
|-----------|------|----------|---------|------|
| ca-service | Deployment | 2 | ca-service | 8000 |
| cert-api | Deployment | 2 | cert-api | 8000 |
| cert-api-spire | Deployment | 1 | — | — |
| cert-worker | Deployment | 1 | — | — |
| pki-database | Deployment | 1 | pki-database | 5432 |

### RabbitMQ
- **Namespace**: rabbitmq
- **Deployment**: rabbitmq (StatefulSet)
- **Service**: rabbitmq (ClusterIP: 5672, 15672)
- **PVC**: data-rabbitmq-0 (1Gi)
- **Status**: Running

### Registry
- **Namespace**: registry
- **Deployment**: registry
- **Services**: registry (ClusterIP: 5000), registry-nodeport (NodePort: 30500)
- **PVC**: registry-data (10Gi)

### Monitoring
- **Namespace**: monitoring
- **Stack**: kube-prometheus-stack
- **Components**:
  - Grafana (NodePort: 32059)
  - Prometheus (StatefulSet)
  - Alertmanager (StatefulSet)
  - kube-state-metrics
  - node-exporter (DaemonSet)
- **Status**: Running, Healthy

---

## Networking

### LoadBalancer Services
| Service | Namespace | External IP | Ports |
|---------|-----------|-------------|-------|
| ejbca-ejbca-ce-nginx | ejbca | 192.168.122.74 | 80:32218, 443:31510 |

### NodePort Services
| Service | Namespace | NodePort | Target |
|---------|-----------|----------|--------|
| argocd-server | argocd | 30721/31588 | 80/443 |
| openbao-ui-nodeport | openbao | 30820 | 8200 |
| kube-prometheus-stack-grafana | monitoring | 32059 | 80 |
| registry-nodeport | registry | 30500 | 5000 |

### ClusterIP Services (Key)
| Service | Namespace | Ports | Purpose |
|---------|-----------|-------|---------|
| kubernetes | default | 443 | API server |
| postgres-postgresql | ejbca | 5432 | EJBCA database |
| openbao | openbao | 8200/8201 | Secrets API |
| cert-api | pki | 8000 | Certificate API |
| ca-service | pki | 8000 | CA abstraction |
| pki-database | pki | 5432 | PKI database |
| rabbitmq | rabbitmq | 5672/15672 | AMQP/Management |
| registry | registry | 5000 | Container registry |
| spire-server | spire | 8081 | SPIRE server |

---

## Persistent Storage

| PVC | Namespace | Size | StorageClass | Status |
|-----|-----------|------|--------------|--------|
| data-postgres-postgresql-0 | ejbca | 10Gi | local-path | Bound |
| prometheus-kube-prometheus-stack-prometheus-db-... | monitoring | 10Gi | local-path | Bound |
| audit-openbao-0 | openbao | 1Gi | local-path | Bound |
| data-openbao-0 | openbao | 5Gi | local-path | Bound |
| cert-inventory-backup | pki | 10Gi | local-path | Bound |
| pki-database-data | pki | 5Gi | local-path | Bound |
| data-rabbitmq-0 | rabbitmq | 1Gi | local-path | Bound |
| registry-data | registry | 10Gi | local-path | Bound |
| spire-data-spire-csi-server-0 | spire | 1Gi | local-path | Bound |
| spire-data-spire-server-0 | spire | 1Gi | local-path | Bound |

**Note**: One PVC pending: `rabbitmq-data-rabbitmq-0` (rabbitmq namespace)

---

## GitOps (Argo CD)

### Applications
| Application | Status | Health | Namespace |
|-------------|--------|--------|-----------|
| cert-manager | Synced | Healthy | cert-manager |
| ejbca | Synced | Healthy | ejbca |
| homelab | Synced | Healthy | default |
| kube-prometheus-stack | Synced | Healthy | monitoring |
| openbao | Synced | Healthy | openbao |
| pki | Synced | Progressing | pki |
| postgres | Synced | Healthy | ejbca |
| rabbitmq | Synced | Progressing | rabbitmq |
| registry | Synced | Healthy | registry |
| spire | Synced | Healthy | spire |

**Repository**: https://github.com/AdamKnight02/homelab-gitops.git (main branch)

---

## Identity

### Kubernetes ServiceAccounts
- Standard K3s service accounts per namespace
- cert-manager service account for cert-manager
- Argo CD service accounts for GitOps

### SPIFFE IDs
- SPIRE server and agent running
- CSI driver providing workload identity
- OIDC discovery provider for external validation

### OpenBao Auth
- Kubernetes auth method configured
- PKI secrets engine mounted
- KV secrets engine mounted

---

## Access Matrix

| Tool | Status | Notes |
|------|--------|-------|
| kubectl | PASS | Client v1.30.0, cluster via SSH proxy |
| argocd CLI | PASS | v3.5.2+e258ee2 |
| Terraform | PASS | v1.10.5 |
| Azure CLI | PASS | Authenticated, RBAC limitations |
| AWS CLI | PASS | Authenticated, AdministratorAccess |
| Docker | FAIL | Not installed |
| Helm | FAIL | Not installed |
| Go | FAIL | Not installed |

---

## Cloud Context

| Cloud | Status | Mode |
|-------|--------|------|
| Azure | PAY-AS-YOU-GO, no credits | **PLAN-ONLY** |
| AWS | Brand new account, likely free-tier | PLAN-ONLY or ephemeral test |
