# Local Architecture Inventory

## Overview

This document provides a factual inventory of the current local PKI homelab environment. All data was collected through direct inspection of the running environment.

**Inventory Date:** 2026-09-02
**Auditor:** PKI Platform Engineer (Agent 5)
**Environment:** frostnode (192.168.1.107) / k8s01 (192.168.122.74)

---

## 1. Compute

### Host Machine

| Attribute | Value |
|-----------|-------|
| Hostname | fedora |
| OS | Fedora Linux 44 (Workstation Edition) |
| Kernel | 7.1.6-201.fc44.x86_64 |
| CPU | Intel Core i7-8550U @ 1.80GHz (8 cores) |
| RAM | 31 GB total, 12 GB available |
| Disk | 929 GB total, 379 GB free (59% used) |
| Primary IP | 192.168.1.107/24 (wlp2s0) |

### Virtual Machine

| Attribute | Value |
|-----------|-------|
| VM Name | k8s01 |
| Hostname | k8s01 |
| OS | RHEL 9.8 |
| IP | 192.168.122.74 |
| vCPU | (detected at runtime) |
| RAM | 11 GB |
| Disk | 36 GB (63% used) |
| Status | Running |

### Kubernetes

| Attribute | Value |
|-----------|-------|
| Distribution | K3s v1.36.2+k3s1 |
| Kubernetes | v1.36.2 |
| Nodes | 1 (single-node cluster) |
| Node Role | control-plane |
| Container Runtime | containerd://2.3.2-k3s2 |
| Pod CIDR | 10.42.0.0/24 |
| Service CIDR | 10.43.0.0/16 |
| CNI | Flannel (K3s default) |
| Storage | local-path (default) |
| LoadBalancer | K3s ServiceLB (klipper-lb) |
| Ingress | None (Traefik disabled) |

### Namespaces (13)

| Namespace | Purpose | Argo Managed |
|-----------|---------|--------------|
| argocd | GitOps platform | Yes |
| cert-manager | Certificate automation | Yes |
| default | Default | No (K3s built-in) |
| ejbca | PKI CA | Yes |
| kube-node-lease | K3s system | No (K3s built-in) |
| kube-public | K3s system | No (K3s built-in) |
| kube-system | K3s core | No (K3s built-in) |
| monitoring | Observability | Yes |
| openbao | Secret management | Yes |
| pki | Certificate services | Yes |
| rabbitmq | Message queue | No (kubectl applied) |
| rabbitmq-demo | Demo workers | No (kubectl applied) |
| registry | Container registry | Yes |
| spire | Workload identity | Yes |

---

## 2. PKI Components

### EJBCA

| Attribute | Value |
|-----------|-------|
| Version | 9.3.7 (Community Edition) |
| Namespace | ejbca |
| Chart | ejbca-ce 9.3.7 |
| Image | keyfactor/ejbca-ce:9.3.7 |
| Nginx Sidecar | nginx:1.27.1 |
| Service | LoadBalancer @ 192.168.122.74:80/443 |

### Certificate Authorities

| CA Name | Subject DN | Type | Issuer | Expires |
|---------|-----------|------|--------|---------|
| LabRootCA | CN=LabRootCA | Root CA | Self-signed | 2036-08-04 |
| LabIssuingCA | CN=LabIssuingCA | Issuing CA | LabRootCA | 2031-08-06 |
| ManagementCA | CN=ManagementCA,O=EJBCA Sample,C=SE | Management | Self-signed | 2036-08-03 |

### Certificate Profiles

| Profile | Status |
|---------|--------|
| Default + custom profiles | Configured |

### End Entity Profiles

| Profile | Status |
|---------|--------|
| Configured profiles | Available |

### Enrollment Protocols

| Protocol | Status |
|----------|--------|
| EST | Available |
| SCEP | Available |
| ACME | Available |
| CMP | Available |
| Web Services (SOAP/XML) | Available |
| REST | Available |

### OCSP and CRL

| Service | Status |
|---------|--------|
| OCSP Responder | Running |
| CRL Distribution | Active |

---

## 3. Platform Components

### PostgreSQL (EJBCA Backend)

| Attribute | Value |
|-----------|-------|
| Chart | bitnami/postgresql 18.8.6 |
| Version | 18.4.0 |
| Namespace | ejbca |
| Architecture | Standalone |
| Storage | local-path (10Gi) |
| Database | ejbcadb |
| User | ejbca |

### OpenBao

| Attribute | Value |
|-----------|-------|
| Chart | openbao 0.29.2 |
| Version | 2.6.2 |
| Namespace | openbao |
| Seal Type | shamir |
| Status | Unsealed |
| Storage | raft (HA enabled) |
| Active Node | https://10.42.0.19:8200 |

**Mounts:**
| Path | Type |
|------|------|
| cubbyhole/ | cubbyhole |
| identity/ | identity |
| pki/ | pki |
| secret/ | kv |
| sys/ | system |

**Auth Methods:**
| Path | Type |
|------|------|
| kubernetes/ | kubernetes |
| spire-cert/ | kubernetes |
| spire-mtls/ | cert |
| token/ | token |

### SPIRE

| Attribute | Value |
|-----------|-------|
| Namespace | spire |
| Trust Domain | homelab.local |
| Server Image | ghcr.io/spiffe/spire-server:1.10.0 |
| Agent Image | ghcr.io/spiffe/spire-agent:1.10.0 |
| Server Status | Running |
| Agent Status | Running |
| Node Attestor | k8s_psat |
| Key Manager | disk (server), memory (agent) |
| DataStore | sqlite3 |

**ClusterSPIFFEID:**
- Template: `spiffe://homelab.local/ns/{{ .PodMeta.Namespace }}/sa/{{ .PodSpec.ServiceAccountName }}`
- Selectors: k8s:ns, k8s:sa

### RabbitMQ

| Attribute | Value |
|-----------|-------|
| Image | rabbitmq:4.1.3-management |
| Namespace | rabbitmq |
| Status | Running |
| Management | Port 15672 |
| AMQP | Port 5672 |
| Argo Managed | No (kubectl applied) |

### cert-manager

| Attribute | Value |
|-----------|-------|
| Chart | jetstack/cert-manager v1.21.1 |
| Namespace | cert-manager |
| CRDs | Enabled |
| Replicas | 1 |

### Registry

| Attribute | Value |
|-----------|-------|
| Image | registry:2.8.3 |
| Namespace | registry |
| Service | NodePort 30500 |
| Status | Running |

---

## 4. Custom Applications

### PKI Applications (namespace: pki)

| App | Image | Replicas | Service | Port |
|-----|-------|----------|---------|------|
| ca-service | 10.42.0.88:5000/ca-service:latest | 2 | ca-service | 8000 |
| cert-api | 10.42.0.88:5000/cert-api:latest | 2 | cert-api | 8000 |
| cert-worker | 10.42.0.88:5000/cert-worker:latest | 1 | - | - |
| pki-database | postgres:16-alpine | 1 | pki-database | 5432 |

---

## 5. GitOps

### Argo CD Applications (9 total)

| Application | Namespace | Source | Sync | Health | Auto Sync |
|-------------|-----------|--------|------|--------|-----------|
| homelab | argocd | GitHub apps/ | Synced | Healthy | No |
| cert-manager | cert-manager | jetstack + GitHub | Synced | Healthy | Yes |
| ejbca | ejbca | GitHub + OCI | Synced | Healthy | No |
| kube-prometheus-stack | monitoring | prometheus-community | Synced | Healthy | Yes |
| openbao | openbao | openbao + GitHub | Synced | Healthy | Yes |
| pki | pki | GitHub apps/pki/ | Synced | Healthy | Yes |
| postgres | ejbca | bitnami | Synced | Healthy | No |
| registry | registry | GitHub | Synced | Healthy | Yes |
| spire | spire | GitHub | Synced | Healthy | Yes |

### Git Repository

| Attribute | Value |
|-----------|-------|
| Repository | https://github.com/AdamKnight02/homelab-gitops.git |
| Local Path | ~/homelab-gitops |
| Branch | main |
| Status | Dirty (uncommitted changes) |

---

## 6. Networking

### Network Map

```
Fedora Host (192.168.1.107)
    |
    |-- virbr0 (192.168.122.1/24)
    |       |
    |       +-- k8s01 VM (192.168.122.74)
    |               |
    |               +-- K3s Pod Network: 10.42.0.0/24
    |               +-- K3s Service Network: 10.43.0.0/16
    |               |
    |               +-- ServiceLB: 192.168.122.74
    |               |       +-- EJBCA: 80/443
    |               |
    |               +-- NodePorts:
    |                       +-- Argo CD: 30721/31588
    |                       +-- Grafana: 32059
    |                       +-- OpenBao: 30820
    |                       +-- Registry: 30500
    |
    |-- virbr1 (192.168.100.1/24)
    |       (no VMs detected)
    |
    +-- WireGuard: 10.168.189.26/32
```

### Service Ports

| Service | Port | Protocol | Access |
|---------|------|----------|--------|
| EJBCA Admin | 443 | HTTPS | LoadBalancer |
| EJBCA Public | 80 | HTTP | LoadBalancer |
| Argo CD | 30721/31588 | HTTPS | NodePort |
| Grafana | 32059 | HTTP | NodePort |
| OpenBao | 30820 | HTTPS | NodePort |
| Registry | 30500 | HTTP | NodePort |

---

## 7. Identity

### Kubernetes ServiceAccounts

| ServiceAccount | Namespace | Purpose |
|----------------|-----------|---------|
| cert-api | pki | Certificate API |
| cert-worker | pki | Certificate worker |
| ca-service | pki | CA abstraction |
| ejbca | ejbca | EJBCA application |
| openbao | openbao | OpenBao server |
| spire-server | spire | SPIRE server |
| spire-agent | spire | SPIRE agent |
| rabbitmq | rabbitmq | RabbitMQ |

### SPIFFE IDs (Active)

| SPIFFE ID | Workload |
|-----------|----------|
| `spiffe://homelab.local/ns/pki/sa/cert-api` | cert-api |
| `spiffe://homelab.local/ns/pki/sa/cert-worker` | cert-worker |
| `spiffe://homelab.local/ns/pki/sa/ca-service` | ca-service |
| `spiffe://homelab.local/ns/ejbca/sa/ejbca` | EJBCA |
| `spiffe://homelab.local/ns/openbao/sa/openbao` | OpenBao |
| `spiffe://homelab.local/ns/spire/sa/spire-server` | SPIRE Server |
| `spiffe://homelab.local/ns/spire/sa/spire-agent` | SPIRE Agent |
| `spiffe://homelab.local/ns/rabbitmq/sa/rabbitmq` | RabbitMQ |

### OpenBao Auth Methods

| Path | Type | Purpose |
|------|------|---------|
| kubernetes/ | kubernetes | K8s SA auth |
| spire-cert/ | kubernetes | SPIRE cert auth |
| spire-mtls/ | cert | SPIRE mTLS auth |
| token/ | token | Direct token auth |

---

## 8. Secrets

### Secret Inventory (Names Only)

| Secret | Namespace | Consumers |
|--------|-----------|-----------|
| ejbca-db-credentials | ejbca | ejbca-ejbca-ce-0 |
| postgres-credentials | ejbca | postgres-postgresql-0 |
| postgres-postgresql | ejbca | postgres-postgresql-0 |
| pki-database-credentials | pki | pki-database |
| openbao-server-tls | openbao | openbao-0 |
| argocd-initial-admin-secret | argocd | argocd-server |
| argocd-secret | argocd | argocd components |
| repo-2132721224 | argocd | argocd-repo-server |
| cert-manager-webhook-ca | cert-manager | cert-manager-webhook |
| homelab-test-tls | cert-manager | - |
| k3s-serving | kube-system | k3s |
| alertmanager-kube-prometheus-stack-alertmanager | monitoring | alertmanager |
| kube-prometheus-stack-grafana | monitoring | grafana |

---

## 9. Known Issues / Deviations

| Issue | Severity | Description |
|-------|----------|-------------|
| RabbitMQ not in GitOps | Medium | kubectl applied, not Argo managed |
| rabbitmq-demo not in GitOps | Low | Demo only |
| Traefik disabled | Medium | No ingress controller |
| Single-node cluster | High | No HA, single point of failure |
| Git working tree dirty | Low | Uncommitted modifications |
| Local registry IP hardcoded | Medium | 10.42.0.88 may change |
| SPIRE sqlite3 datastore | Low | Consider PostgreSQL for HA |

---

## 10. Resource Summary

### Helm Releases

| Release | Namespace | Chart | Version | Status |
|---------|-----------|-------|---------|--------|
| ejbca | ejbca | ejbca-ce | 9.3.7 | deployed |
| kube-prometheus-stack | monitoring | kube-prometheus-stack | 88.5.4 | deployed |
| postgres | ejbca | postgresql | 18.8.6 | deployed |

### Persistent Volumes

| Claim | Namespace | Size | StorageClass |
|-------|-----------|------|--------------|
| postgres-postgresql-0 | ejbca | 10Gi | local-path |
| openbao-data | openbao | 5Gi | local-path |
| openbao-audit | openbao | 1Gi | local-path |
| spire-data | spire | 1Gi | local-path |

---

*End of Local Architecture Inventory*
