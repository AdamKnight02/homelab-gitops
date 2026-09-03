# GitOps Design

> **Status**: Architecture defined, overlays to be implemented

## Philosophy

```
Terraform = Infrastructure (VM, network, storage)
Argo CD   = Applications (K3s, PKI platform, services)
Git       = Single source of truth
```

## Repository Structure

```
apps/
├── base/                          # Base configurations
│   ├── k3s-system/               # K3s system components
│   ├── cert-manager/             # TLS certificate management
│   ├── argocd/                   # GitOps controller
│   ├── ejbca/                    # PKI engine
│   ├── openbao/                  # Secrets management
│   ├── spire/                    # Workload identity
│   ├── rabbitmq/                 # Message queue
│   ├── cert-api/                 # Certificate API
│   ├── cert-worker/              # Certificate worker
│   ├── pki-database/             # PostgreSQL for PKI
│   └── monitoring/               # Prometheus/Grafana
│
└── overlays/
    ├── homelab/                  # Local environment
    │   ├── kustomization.yaml
    │   ├── patches/
    │   └── values/
    │
    ├── azure/                    # Azure environment
    │   ├── kustomization.yaml
    │   ├── patches/
    │   │   ├── nodeport-patch.yaml
    │   │   ├── storage-class-patch.yaml
    │   │   └── resource-limits-patch.yaml
    │   └── values/
    │       ├── ejbca-values.yaml
    │       ├── openbao-values.yaml
    │       └── rabbitmq-values.yaml
    │
    └── aws/                      # AWS environment
        ├── kustomization.yaml
        ├── patches/
        │   ├── nodeport-patch.yaml
        │   ├── storage-class-patch.yaml
        │   └── resource-limits-patch.yaml
        └── values/
            ├── ejbca-values.yaml
            ├── openbao-values.yaml
            └── rabbitmq-values.yaml
```

## Argo CD Application Structure

### Root Application (App of Apps)

```yaml
# apps/cloud-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/AdamKnight02/homelab-gitops.git
    targetRevision: main
    path: apps/overlays/{{environment}}
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Individual Applications

```yaml
# Example: EJBCA application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ejbca
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/AdamKnight02/homelab-gitops.git
    targetRevision: main
    path: apps/base/ejbca
    helm:
      valueFiles:
        - ../../overlays/{{environment}}/values/ejbca-values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ejbca
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Environment-Specific Configurations

### Homelab Overlay

```yaml
# apps/overlays/homelab/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/cert-manager
  - ../../base/ejbca
  - ../../base/openbao
  - ../../base/spire
  - ../../base/rabbitmq
  - ../../base/cert-api
  - ../../base/cert-worker
  - ../../base/pki-database
  - ../../base/monitoring

patches:
  - path: patches/storage-class-patch.yaml
    target:
      kind: PersistentVolumeClaim
  - path: patches/resource-limits-patch.yaml
    target:
      kind: Deployment
```

### Azure Overlay

```yaml
# apps/overlays/azure/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/cert-manager
  - ../../base/ejbca
  - ../../base/openbao
  - ../../base/spire
  - ../../base/rabbitmq
  - ../../base/cert-api
  - ../../base/cert-worker
  - ../../base/pki-database

patches:
  - path: patches/storage-class-patch.yaml
    target:
      kind: PersistentVolumeClaim
  - path: patches/nodeport-patch.yaml
    target:
      kind: Service
  - path: patches/resource-limits-patch.yaml
    target:
      kind: Deployment
```

### AWS Overlay

```yaml
# apps/overlays/aws/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/cert-manager
  - ../../base/ejbca
  - ../../base/openbao
  - ../../base/spire
  - ../../base/rabbitmq
  - ../../base/cert-api
  - ../../base/cert-worker
  - ../../base/pki-database

patches:
  - path: patches/storage-class-patch.yaml
    target:
      kind: PersistentVolumeClaim
  - path: patches/nodeport-patch.yaml
    target:
      kind: Service
  - path: patches/resource-limits-patch.yaml
    target:
      kind: Deployment
```

## Key Differences Between Environments

| Aspect | Homelab | Azure | AWS |
|--------|---------|-------|-----|
| Storage Class | local-path | managed-premium | gp2 |
| NodePort Range | 30000-32767 | 30000-32767 | 30000-32767 |
| Resource Limits | Higher | Lower (B1s) | Lower (t2.micro) |
| Monitoring | Full stack | Minimal | Minimal |
| Ingress | Traefik | NodePort | NodePort |
| TLS | cert-manager | cert-manager | cert-manager |

## Sync Strategy

### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true      # Remove resources not in Git
    selfHeal: true   # Reconcile drift
    allowEmpty: false
```

### Manual Sync (for sensitive operations)

```yaml
syncPolicy:
  automated:
    prune: false
    selfHeal: false
```

## Rollback Strategy

1. **Git revert**: Revert to previous commit
2. **Argo CD rollback**: Use UI or CLI to rollback
3. **Manual intervention**: For complex failures

## Secrets Management

### External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ejbca-db-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: openbao-backend
  target:
    name: ejbca-db-credentials
  data:
    - secretKey: username
      remoteRef:
        key: secret/data/ejbca/db
        property: username
    - secretKey: password
      remoteRef:
        key: secret/data/ejbca/db
        property: password
```

## Validation

```bash
# Validate Kustomize builds
kustomize build apps/overlays/homelab
kustomize build apps/overlays/azure
kustomize build apps/overlays/aws

# Validate with kubeval
kustomize build apps/overlays/homelab | kubeval

# Dry-run apply
kustomize build apps/overlays/homelab | kubectl apply --dry-run=client -f -
```
