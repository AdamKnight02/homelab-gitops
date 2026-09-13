# PKI/Kubernetes Homelab — Full Inventory Report

**Generated:** 2026-08-28 01:20 CDT  
**Auditor:** OpenClaw Agent  
**Status:** Phase 0 Complete — Ready for Review

---

## 1. ACCESS MATRIX

| System | Access | Details |
|--------|--------|---------|
| Fedora host (frostnode) | ✅ AVAILABLE | Local shell |
| k8s01 VM (192.168.122.74) | ✅ AVAILABLE | SSH as openclaw, sudo OK |
| Kubernetes (K3s) | ✅ AVAILABLE | Admin access via /etc/rancher/k3s/k3s.yaml |
| Helm | ✅ AVAILABLE | 3 releases active |
| Argo CD | ✅ AVAILABLE | 9 Applications, UI via NodePort |
| GitHub repo | ✅ AVAILABLE | Read/write, dirty working tree |
| OpenBao | ✅ AVAILABLE | Unsealed, PKI and KV mounts active |
| EJBCA CLI | ✅ AVAILABLE | CA list functional |

---

## 2. TOOL MATRIX

| Tool | Status | Notes |
|------|--------|-------|
| ssh | ✅ AVAILABLE | /usr/bin/ssh |
| git | ✅ AVAILABLE | /usr/bin/git |
| gh | ✅ AVAILABLE | /usr/bin/gh |
| code | ✅ AVAILABLE | /usr/bin/code |
| jq | ✅ AVAILABLE | /usr/bin/jq |
| curl | ✅ AVAILABLE | /usr/bin/curl |
| openssl | ✅ AVAILABLE | /usr/bin/openssl |
| podman | ✅ AVAILABLE | /usr/bin/podman |
| virsh | ✅ AVAILABLE | /usr/bin/virsh |
| kubectl | ❌ NOT FOUND | Only on k8s01 VM |
| helm | ❌ NOT FOUND | Only on k8s01 VM |
| argocd | ❌ NOT FOUND | Only on k8s01 VM |
| yq | ❌ NOT FOUND | Install if needed |
| docker | ❌ NOT FOUND | Podman available instead |
| buildah | ❌ NOT FOUND | Install if needed |
| k9s | ❌ NOT FOUND | Install if needed |

---

## 3. FEDORA HOST INVENTORY

| Attribute | Value |
|-----------|-------|
| Hostname | fedora |
| OS | Fedora Linux 44 (Workstation Edition) |
| Kernel | 7.1.6-201.fc44.x86_64 |
| CPU | Intel Core i7-8550U @ 1.80GHz (8 cores) |
| RAM | 31 GB total, 12 GB available |
| Disk | 929 GB total, 379 GB free (59% used) |
| Primary IP | 192.168.1.107/24 (wlp2s0) |
| WireGuard | 10.168.189.26/32 (wg0-mullvad) |
| WireGuard Home | 10.77.0.1/24 (wg-home) |
| libvirt nets | 192.168.122.0/24 (virbr0), 192.168.100.0/24 (virbr1) |

---

## 4. VM INVENTORY

| VM | Hostname | OS | IP | vCPU | RAM | Disk | Status |
|----|----------|-----|-----|------|-----|------|--------|
| k8s01 | k8s01 | RHEL 9.8 | 192.168.122.74 | ? | 11 GB | 36 GB (63% used) | ✅ Running |

**Note:** Only k8s01 detected. No other libvirt VMs found.

---

## 5. KUBERNETES INVENTORY

### Cluster Overview
| Attribute | Value |
|-----------|-------|
| Distribution | K3s v1.36.2+k3s1 |
| Kubernetes | v1.36.2 |
| Nodes | 1 (single-node cluster) |
| Node Role | control-plane |
| Container Runtime | containerd://2.3.2-k3s2 |
| Pod CIDR | 10.42.0.0/24 |
| Service CIDR | 10.43.0.0/16 (inferred) |
| CNI | Flannel (K3s default) |
| Storage | local-path (default) |
| LoadBalancer | K3s ServiceLB (klipper-lb) |
| Ingress | None (Traefik disabled) |

### Namespaces (13)
| Namespace | Purpose | Argo Managed |
|-----------|---------|--------------|
| argocd | GitOps platform | ✅ Yes (homelab app) |
| cert-manager | Certificate automation | ✅ Yes |
| default | Default | ❌ K3s built-in |
| ejbca | PKI CA | ✅ Yes |
| kube-node-lease | K3s system | ❌ K3s built-in |
| kube-public | K3s system | ❌ K3s built-in |
| kube-system | K3s core | ❌ K3s built-in |
| monitoring | Observability | ✅ Yes |
| openbao | Secret management | ✅ Yes |
| pki | Certificate services | ✅ Yes |
| rabbitmq | Message queue | ❌ **NOT ARGO MANAGED** |
| rabbitmq-demo | Demo workers | ❌ **NOT ARGO MANAGED** |
| registry | Container registry | ✅ Yes |
| spire | Workload identity | ✅ Yes |

---

## 6. HELM INVENTORY

| Release | Namespace | Chart | Version | App Version | Status |
|---------|-----------|-------|---------|-------------|--------|
| ejbca | ejbca | ejbca-ce | 9.3.7 | 9.3.7 | deployed |
| kube-prometheus-stack | monitoring | kube-prometheus-stack | 88.5.4 | v0.93.1 | deployed |
| postgres | ejbca | postgresql | 18.8.6 | 18.4.0 | deployed |

**Helm Repos:** jetstack, openbao, bitnami, spiffe, prometheus-community

---

## 7. ARGO APPLICATION INVENTORY

| Application | Namespace | Source | Chart/Path | Version | Sync | Health | Auto Sync | Prune | Self Heal |
|-------------|-----------|--------|------------|---------|------|--------|-----------|-------|-----------|
| homelab | argocd | GitHub | apps/ | main | Synced | Healthy | ❌ | ❌ | ❌ |
| cert-manager | cert-manager | jetstack + GitHub | cert-manager | v1.21.1 | Synced | Healthy | ✅ | ✅ | ✅ |
| ejbca | ejbca | GitHub + OCI | ejbca-ce | 9.3.7 | Synced | Healthy | ❌ | ❌ | ❌ |
| kube-prometheus-stack | monitoring | prometheus-community | kube-prometheus-stack | 75.13.0 | Synced | Healthy | ✅ | ✅ | ✅ |
| openbao | openbao | openbao + GitHub | openbao | 0.29.2 | Synced | Healthy | ✅ | ✅ | ✅ |
| pki | pki | GitHub | apps/pki/ | main | Synced | Healthy | ✅ | ✅ | ✅ |
| postgres | ejbca | bitnami | postgresql | 18.8.6 | Synced | Healthy | ❌ | ❌ | ❌ |
| registry | registry | GitHub | infrastructure/registry/ | main | Synced | Healthy | ✅ | ✅ | ✅ |
| spire | spire | GitHub | apps/spire/ | main | Synced | Healthy | ✅ | ✅ | ✅ |

**Note:** ejbca and postgres have `ignoreDifferences` configured for Helm-managed fields.

---

## 8. ARGO TRACKING COVERAGE MATRIX

| Component | Namespace | Argo Managed | Source | Notes |
|-----------|-----------|--------------|--------|-------|
| EJBCA | ejbca | ✅ FULL | apps/ejbca/ | Helm chart via Argo |
| PostgreSQL | ejbca | ✅ FULL | apps/postgres/ | Helm chart via Argo |
| cert-manager | cert-manager | ✅ FULL | apps/cert-manager/ | Helm + manifests |
| kube-prometheus-stack | monitoring | ✅ FULL | kube-prometheus-stack | Helm chart |
| OpenBao | openbao | ✅ FULL | apps/openbao/ | Helm + manifests |
| PKI apps (cert-api, cert-worker, ca-service, database) | pki | ✅ FULL | apps/pki/ | Kustomize |
| SPIRE | spire | ✅ FULL | apps/spire/ | Kustomize |
| Registry | registry | ✅ FULL | infrastructure/registry/ | Kustomize |
| **RabbitMQ** | **rabbitmq** | ❌ **NONE** | **kubectl applied** | **NEEDS ARGO APP** |
| **rabbitmq-demo** | **rabbitmq-demo** | ❌ **NONE** | **kubectl applied** | **NEEDS ARGO APP** |
| K3s builtins (coredns, local-path, metrics-server) | kube-system | ❌ BOOTSTRAP | K3s | Expected |
| K3s ServiceLB | kube-system | ❌ BOOTSTRAP | K3s | Expected |

---

## 9. UNTRACKED / MANUALLY MANAGED RESOURCES

| Namespace | Kind | Name | Purpose | Management | Should Move? | Risk |
|-----------|------|------|---------|------------|--------------|------|
| rabbitmq | StatefulSet | rabbitmq | Message queue | kubectl apply | ✅ Yes | LOW — stateless config |
| rabbitmq | Service | rabbitmq | AMQP/Management | kubectl apply | ✅ Yes | LOW |
| rabbitmq-demo | Deployment | rabbitmq-worker | Demo consumers | kubectl apply | ⚠️ Optional | LOW — demo only |
| rabbitmq-demo | Job | rabbitmq-producer | Demo producer | kubectl apply | ⚠️ Optional | LOW — one-shot |
| kube-system | DaemonSet | svclb-ejbca-ejbca-ce-nginx | K3s ServiceLB | K3s auto | ❌ No | BOOTSTRAP |
| kube-system | Deployment | local-path-provisioner | Storage | K3s auto | ❌ No | BOOTSTRAP |
| kube-system | Deployment | metrics-server | Metrics | K3s auto | ❌ No | BOOTSTRAP |
| kube-system | Deployment | coredns | DNS | K3s auto | ❌ No | BOOTSTRAP |

---

## 10. GIT REPOSITORY INVENTORY

| Attribute | Value |
|-----------|-------|
| Repository | https://github.com/AdamKnight02/homelab-gitops.git |
| Local Path | ~/homelab-gitops |
| Branch | main |
| Status | Dirty (uncommitted changes) |
| Uncommitted | apps/pki/cert-worker/main.py (modified) |
| Untracked | apps/pki/cert-api/models.py, apps/pki/cert-worker/models.py, infrastructure/k3s-pod-watcher/ |
| Total Files | 52 YAML files |

---

## 11. PKI INVENTORY (EJBCA)

| CA Name | Subject DN | Type | Issuer | Expires |
|---------|-----------|------|--------|---------|
| LabRootCA | CN=LabRootCA | Root CA | Self-signed | 2036-08-04 |
| LabIssuingCA | CN=LabIssuingCA | Issuing CA | LabRootCA | 2031-08-06 |
| ManagementCA | CN=ManagementCA,O=EJBCA Sample,C=SE | Management | Self-signed | 2036-08-03 |

**EJBCA Deployment:**
- Chart: ejbca-ce 9.3.7
- Image: keyfactor/ejbca-ce:9.3.7
- Nginx sidecar: nginx:1.27.1
- Database: PostgreSQL (bitnami/postgresql:latest)
- Service: LoadBalancer @ 192.168.122.74:80/443

---

## 12. OPENBAO INVENTORY

| Attribute | Value |
|-----------|-------|
| Namespace | openbao |
| Chart | openbao 0.29.2 |
| Version | 2.6.2 |
| Seal Type | shamir |
| Status | **Unsealed** (fixed during audit) |
| Storage | raft (HA enabled) |
| Active Node | https://10.42.0.19:8200 |

**Mounts:**
| Path | Type | Description |
|------|------|-------------|
| cubbyhole/ | cubbyhole | Per-token storage |
| identity/ | identity | Identity store |
| pki/ | pki | PKI engine |
| secret/ | kv | Key-value store |
| sys/ | system | System endpoints |

**Auth Methods:**
| Path | Type | Description |
|------|------|-------------|
| kubernetes/ | kubernetes | K8s service account auth |
| spire-cert/ | kubernetes | SPIRE cert auth |
| spire-mtls/ | cert | SPIRE mTLS auth |
| token/ | token | Token auth |

**Policies:** default, lab-policy, pki-api-policy, pki-worker-policy, root

---

## 13. SPIFFE/SPIRE INVENTORY

| Attribute | Value |
|-----------|-------|
| Namespace | spire |
| Trust Domain | homelab.local |
| Server Image | ghcr.io/spiffe/spire-server:1.10.0 |
| Agent Image | ghcr.io/spiffe/spire-agent:1.10.0 |
| Server Status | **Running** (fixed during audit) |
| Agent Status | Running |
| Node Attestor | k8s_psat |
| Key Manager | disk |
| DataStore | sqlite3 |

**ClusterSPIFFEID:**
- Name: default
- Template: `spiffe://homelab.local/ns/{{ .PodMeta.Namespace }}/sa/{{ .PodSpec.ServiceAccountName }}`
- Selectors: k8s:ns, k8s:sa

**Fix Applied:** NetworkPolicy egress rule corrected to allow kube-apiserver access.

---

## 14. APPLICATION / MESSAGING INVENTORY

### PKI Applications (namespace: pki)
| App | Image | Replicas | Service | Port | Argo |
|-----|-------|----------|---------|------|------|
| ca-service | 10.42.0.88:5000/ca-service:latest | 2 | ca-service | 8000 | ✅ |
| cert-api | 10.42.0.88:5000/cert-api:latest | 2 | cert-api | 8000 | ✅ |
| cert-worker | 10.42.0.88:5000/cert-worker:latest | 1 | — | — | ✅ |
| pki-database | postgres:16-alpine | 1 | pki-database | 5432 | ✅ |

### RabbitMQ (namespace: rabbitmq)
| Component | Image | Status | Argo |
|-----------|-------|--------|------|
| rabbitmq | rabbitmq:4.1.3-management | Running | ❌ |

### Registry (namespace: registry)
| Component | Image | Status | Argo |
|-----------|-------|--------|------|
| registry | registry:2.8.3 | Running | ✅ |

---

## 15. OBSERVABILITY INVENTORY

| Component | Namespace | Status | Argo |
|-----------|-----------|--------|------|
| Prometheus | monitoring | Running | ✅ |
| Alertmanager | monitoring | Running | ✅ |
| Grafana | monitoring | Running | ✅ |
| Node Exporter | monitoring | Running | ✅ |
| kube-state-metrics | monitoring | Running | ✅ |
| ServiceMonitors | monitoring | 13 active | ✅ |
| PrometheusRules | monitoring | 35 rule groups | ✅ |

**Grafana Access:** NodePort @ :32059

---

## 16. NETWORK MAP

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

---

## 17. SECRET DEPENDENCY MAP (No Values Exposed)

| Secret | Namespace | Consumers | Purpose |
|--------|-----------|-----------|---------|
| ejbca-db-credentials | ejbca | ejbca-ejbca-ce-0 | DB credentials |
| postgres-credentials | ejbca | postgres-postgresql-0 | PostgreSQL auth |
| postgres-postgresql | ejbca | postgres-postgresql-0 | PostgreSQL config |
| pki-database-credentials | pki | pki-database | PKI DB credentials |
| openbao-server-tls | openbao | openbao-0 | Server TLS |
| argocd-initial-admin-secret | argocd | argocd-server | Admin password |
| argocd-secret | argocd | argocd components | Argo config |
| repo-2132721224 | argocd | argocd-repo-server | Git repo creds |
| cert-manager-webhook-ca | cert-manager | cert-manager-webhook | Webhook CA |
| homelab-test-tls | cert-manager | — | Test certificate |
| k3s-serving | kube-system | k3s | API server TLS |
| alertmanager-kube-prometheus-stack-alertmanager | monitoring | alertmanager | Alertmanager config |
| kube-prometheus-stack-grafana | monitoring | grafana | Grafana config |

---

## 18. PHASE 1-7 VERIFICATION

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Phase 1 | K3s / Kubernetes base | ✅ VERIFIED COMPLETE | Single-node K3s v1.36.2 |
| Phase 2 | EJBCA Community + PostgreSQL | ✅ VERIFIED COMPLETE | 3 CAs active |
| Phase 3 | Argo CD + GitHub integration | ✅ VERIFIED COMPLETE | App-of-Apps pattern |
| Phase 4 | GitOps repository + App-of-Apps | ✅ VERIFIED COMPLETE | 9 Applications |
| Phase 5 | EJBCA/PostgreSQL under Argo | ✅ VERIFIED COMPLETE | Both Argo-managed |
| Phase 6 | Supporting platform services | ✅ VERIFIED COMPLETE | OpenBao, SPIRE, registry |
| Phase 7 | Prometheus/Grafana observability | ✅ VERIFIED COMPLETE | Full stack deployed |

---

## 19. CURRENT ARGO DRIFT / OUTOFSYNC

| Application | Status | Drift Type | Action |
|-------------|--------|------------|--------|
| All applications | Synced | None detected | None |

**Previous Issues (Fixed):**
- OpenBao: was Progressing (sealed) → **Unsealed, now Healthy**
- SPIRE: was Progressing (CrashLoopBackOff) → **Fixed NetworkPolicy, now Healthy**

---

## 20. DISCOVERED ARCHITECTURE DEVIATIONS

| Deviation | Expected | Actual | Impact |
|-----------|----------|--------|--------|
| RabbitMQ not in GitOps | Argo managed | kubectl applied | **MEDIUM** — untracked workload |
| rabbitmq-demo not in GitOps | Argo managed | kubectl applied | **LOW** — demo only |
| Traefik disabled | Ingress available | No ingress controller | **MEDIUM** — services exposed via NodePort/LB only |
| Single-node cluster | Multi-node HA | Single node | **HIGH** — no HA, single point of failure |
| Git working tree dirty | Clean | Modified + untracked files | **LOW** — commit needed |
| Local registry IP hardcoded | DNS name | 10.42.0.88:5000 | **MEDIUM** — IP may change on pod restart |

---

## 21. RISKS

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Single-node K3s — no HA | HIGH | Certain | Document; plan multi-node |
| OpenBao unseal manual | HIGH | Certain | Document keys; consider auto-unseal |
| RabbitMQ untracked | MEDIUM | Likely | Create Argo Application |
| Local registry IP ephemeral | MEDIUM | Likely | Use ClusterIP service name |
| No Ingress controller | MEDIUM | N/A | NodePort/LB acceptable for lab |
| EJBCA LoadBalancer on single node | LOW | N/A | Acceptable for lab |
| SPIRE sqlite3 datastore | LOW | Possible | Consider PostgreSQL for HA |
| Git dirty working tree | LOW | Certain | Commit changes |

---

## 22. PROPOSED ARGO OWNERSHIP STRUCTURE

For currently untracked resources:

```
homelab (root app)
│
├── apps/
│   ├── cert-manager/          ✅ Already managed
│   ├── ejbca/                 ✅ Already managed
│   ├── openbao/               ✅ Already managed
│   ├── pki/                   ✅ Already managed
│   ├── postgres/              ✅ Already managed
│   ├── spire/                 ✅ Already managed
│   ├── rabbitmq/              ❌ PROPOSED — new Argo app
│   └── rabbitmq-demo/         ❌ PROPOSED — new Argo app (optional)
│
└── infrastructure/
    ├── registry/              ✅ Already managed
    └── k3s-pod-watcher/       ❌ Untracked folder in git
```

---

## 23. RECOMMENDED PHASE 8-24 EXECUTION ORDER

| Priority | Phase | Description | Depends On | Effort |
|----------|-------|-------------|------------|--------|
| P0 | **Git cleanup** | Commit dirty working tree | — | 15 min |
| P0 | **RabbitMQ Argo** | Create Argo app for RabbitMQ | Git cleanup | 30 min |
| P1 | Phase 8 | PKI Health + Observability | — | 4-6 hrs |
| P1 | Phase 9 | SPIFFE/SPIRE workload identity | SPIRE fixed | 2-3 hrs |
| P1 | Phase 10 | Service-to-service mTLS | Phase 9 | 3-4 hrs |
| P2 | Phase 11 | OpenBao workload authentication | Phase 9 | 2-3 hrs |
| P2 | Phase 12 | Full certificate lifecycle | Phase 8-11 | 4-6 hrs |
| P3 | Phase 13 | Crypto inventory | Phase 12 | 3-4 hrs |
| P3 | Phase 14 | Certificate discovery | Phase 13 | 2-3 hrs |
| P3 | Phase 15 | Automated renewal | Phase 12-14 | 4-6 hrs |
| P4 | Phase 16 | Revocation/OCSP/CRL | Phase 12 | 3-4 hrs |
| P4 | Phase 17 | Certificate policy engine | Phase 12 | 3-4 hrs |
| P4 | Phase 18 | PQC readiness | Phase 13 | 2-3 hrs |
| P5 | Phase 19 | Security hardening | All above | 4-6 hrs |
| P5 | Phase 20 | Backup + DR | All above | 4-6 hrs |
| P5 | Phase 21 | Failure testing | Phase 20 | 3-4 hrs |
| P6 | Phase 22 | GitOps maturity | All above | 2-3 hrs |
| P6 | Phase 23 | CI validation | Phase 22 | 3-4 hrs |
| P7 | Phase 24 | Architecture documentation | All above | 4-6 hrs |

---

## 24. FIXES APPLIED DURING AUDIT

| Fix | Component | Issue | Resolution |
|-----|-----------|-------|------------|
| 1 | OpenBao | Sealed (Progressing) | Unsealed with 3/5 shamir keys |
| 2 | SPIRE server | CrashLoopBackOff | Fixed NetworkPolicy egress to allow kube-apiserver access |

---

## APPENDIX: IMMEDIATE ACTION ITEMS

1. **Commit git changes** — Working tree has uncommitted modifications
2. **Create RabbitMQ Argo Application** — Currently kubectl-managed
3. **Document OpenBao unseal procedure** — Manual step needed on restart
4. **Fix local registry reference** — Use service DNS instead of pod IP
5. **Review ejbca/postgres auto-sync** — Currently manual sync only

---

*End of Inventory Report*
