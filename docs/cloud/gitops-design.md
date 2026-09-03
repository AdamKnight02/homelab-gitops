# GitOps Design

> **Purpose**: Define how GitOps (Argo CD) manages the PKI platform across environments.

## Philosophy

```
Terraform = Infrastructure (VM, network, IAM)
Argo CD   = Platform (K3s, EJBCA, OpenBao, SPIRE, etc.)
```

Terraform creates the VM and bootstraps K3s + Argo CD.
Argo CD manages all platform workloads from Git.

## Repository Structure

```
apps/
├── base/                          # Base configurations
│   ├── k3s/                       # K3s components
│   ├── cert-manager/              # cert-manager
│   ├── ejbca/                     # EJBCA + PostgreSQL
│   ├── openbao/                   # OpenBao
│   ├── spire/                     # SPIRE
│   ├── rabbitmq/                  # RabbitMQ
│   ├── monitoring/                # Prometheus + Grafana
│   ├── registry/                  # Container registry
│   └── pki-platform/              # cert-api, cert-worker, etc.
│
└── overlays/
    ├── homelab/                   # Local homelab customizations
    │   ├── kustomization.yaml
    │   └── patches/
    ├── azure/                     # Azure customizations
    │   ├── kustomization.yaml
    │   └── patches/
    └── aws/                       # AWS customizations
        ├── kustomization.yaml
        └── patches/
```

## Argo CD Applications

### Current Homelab Applications

| Application | Namespace | Source | Sync Status |
|-------------|-----------|--------|-------------|
| cert-manager | cert-manager | Helm | Synced |
| ejbca | ejbca | Helm | Synced |
| homelab | default | Kustomize | Synced |
| kube-prometheus-stack | monitoring | Helm | Synced |
| openbao | openbao | Helm | Synced |
| pki | pki | Kustomize | Synced |
| postgres | ejbca | Helm | Synced |
| rabbitmq | rabbitmq | Helm | Synced |
| registry | registry | Helm | Synced |
| spire | spire | Helm | Synced |

### Cloud Overlay Strategy

Each cloud environment uses the same base configurations with environment-specific patches:

```yaml
# overlays/azure/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/ejbca
  - ../../base/openbao
  - ../../base/spire
  - ../../base/rabbitmq
  - ../../base/pki-platform
  - ../../base/monitoring

patches:
  - path: patches/node-selector.yaml
  - path: patches/storage-class.yaml
  - path: patches/ingress-hosts.yaml
```

### Key Differences by Environment

| Aspect | Homelab | Azure | AWS |
|--------|---------|-------|-----|
| StorageClass | local-path | local-path (K3s default) | local-path (K3s default) |
| Ingress | Nginx (K3s) | Nginx (K3s) | Nginx (K3s) |
| LoadBalancer | MetalLB/K3s | Cloud provider LB | Cloud provider LB |
| NodeSelector | None | None | None |
| Replicas | 1-2 | 1-2 | 1-2 |
| Resources | Minimal | Minimal | Minimal |

## Bootstrap Sequence

```
1. Terraform creates VM
2. cloud-init installs K3s
3. cloud-init installs Argo CD
4. Argo CD connects to Git repository
5. Argo CD syncs applications
6. Platform is ready
```

## Application of Record

The Git repository is the single source of truth:

```
Git Repository
    |
    v
Argo CD
    |
    v
Kubernetes
    |
    v
PKI Platform
```

Any manual changes to Kubernetes are:
1. Detected by Argo CD (drift detection)
2. Reverted on next sync
3. Should be made in Git instead

## Secrets Management

Argo CD uses:
- **External Secrets Operator** or **Sealed Secrets** for Git-encrypted secrets
- **OpenBao** for runtime secret injection
- **SPIFFE** for workload-to-workload authentication

No secrets are stored in plain text in Git.

## Multi-Environment Promotion

```
Local (homelab)
    |
    v (validate)
Staging (if exists)
    |
    v (validate)
Cloud (azure/aws)
```

For this lab, environments are independent — there is no promotion pipeline.
