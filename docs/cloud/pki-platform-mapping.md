# PKI Platform Component Mapping

## Overview

This document maps each component of the local PKI homelab into cloud-neutral, reusable Kubernetes workloads. It identifies what stays identical across environments and what requires provider-specific integration.

---

## Component Inventory

### 1. EJBCA Community Edition

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Image** | `keyfactor/ejbca-ce:9.3.7` | Same | Identical container |
| **Chart** | `ejbca-ce` (OCI) | Same | `oci://repo.keyfactor.com/charts/ejbca-ce` |
| **Version** | `9.3.7` | Same | Pin version for reproducibility |
| **Database** | PostgreSQL (Bitnami) | Same | `bitnami/postgresql` chart |
| **Storage** | `local-path` (5Gi) | Cloud CSI | Azure Disk / AWS EBS |
| **Service Type** | LoadBalancer | LoadBalancer | Cloud LB maps to VM |
| **Nginx Sidecar** | `nginx:1.27.1` | Same | TLS termination |
| **Replicas** | 1 | 1 | Stateful, single instance |

**Configuration Differences:**
- Database JDBC URL: `jdbc:postgresql://postgres-postgresql:5432/ejbcadb` (same in K8s)
- Storage class: environment-specific
- LoadBalancer IP: cloud assigns automatically

**Cloud-Neutral Manifest:**
```yaml
# apps/ejbca/values.yaml (same across environments)
database:
  type: postgres
ejbca:
  env:
    DATABASE_JDBC_URL: jdbc:postgresql://postgres-postgresql:5432/ejbcadb
  envRaw:
    - name: DATABASE_USER
      value: ejbca
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgres-postgresql
          key: password
nginx:
  enabled: true
  initializeWithSelfSignedTls: true
  service:
    type: LoadBalancer
```

---

### 2. PostgreSQL (EJBCA Backend)

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Image** | `bitnami/postgresql:18.4.0` | Same | Bitnami chart |
| **Chart** | `bitnami/postgresql` `18.8.6` | Same | Pin chart version |
| **Architecture** | Standalone | Standalone | HA via Patroni (future) |
| **Storage** | `local-path` (10Gi) | Cloud CSI | Environment-specific |
| **Credentials** | Secret `postgres-postgresql` | Same | Auto-generated or sealed |
| **Database** | `ejbcadb` | Same | Same schema |
| **User** | `ejbca` | Same | Same permissions |

**Cloud-Neutral Manifest:**
```yaml
# apps/postgres/values.yaml (same across environments)
architecture: standalone
auth:
  username: ejbca
  database: ejbcadb
  existingSecret: postgres-postgresql
  secretKeys:
    adminPasswordKey: postgres-password
    userPasswordKey: password
primary:
  persistence:
    enabled: true
    size: 10Gi
    storageClass: local-path  # <-- overlay per environment
```

---

### 3. OpenBao

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Image** | `openbao:2.6.2` | Same | Official image |
| **Chart** | `openbao/openbao` `0.29.2` | Same | Pin chart version |
| **Mode** | Standalone (Raft) | Standalone (Raft) | HA mode future |
| **Storage** | `local-path` (5Gi data + 1Gi audit) | Cloud CSI | Environment-specific |
| **TLS** | cert-manager issued | Same | `openbao-server-tls` secret |
| **Auth Methods** | K8s, SPIFFE, Token | Same | Same configuration |
| **Mounts** | PKI, KV, Identity | Same | Same paths |

**Cloud-Neutral Manifest:**
```yaml
# apps/openbao/values.yaml (same across environments)
global:
  tlsDisable: false
server:
  enabled: true
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  dataStorage:
    enabled: true
    size: 5Gi
    storageClass: local-path  # <-- overlay per environment
  auditStorage:
    enabled: true
    size: 1Gi
    storageClass: local-path  # <-- overlay per environment
  service:
    type: ClusterIP
  ingress:
    enabled: false
  dev:
    enabled: false
  standalone:
    enabled: true
    config: |
      ui = true
      listener "tcp" {
        tls_disable = 0
        address = "[::]:8200"
        cluster_address = "[::]:8201"
        tls_cert_file = "/openbao/userconfig/server-tls/tls.crt"
        tls_key_file  = "/openbao/userconfig/server-tls/tls.key"
      }
      storage "raft" {
        path = "/openbao/data"
      }
      service_registration "kubernetes" {}
  volumes:
    - name: server-tls
      secret:
        secretName: openbao-server-tls
  volumeMounts:
    - name: server-tls
      mountPath: /openbao/userconfig/server-tls
      readOnly: true
injector:
  enabled: false
ui:
  enabled: true
```

**Post-Deployment Configuration (Same Everywhere):**
```bash
# Initialize and unseal
bao operator init -tls-skip-verify
bao operator unseal -tls-skip-verify <key>

# Enable auth methods
bao auth enable -tls-skip-verify kubernetes
bao auth enable -tls-skip-verify cert

# Configure Kubernetes auth
bao write -tls-skip-verify auth/kubernetes/config \
  token_reviewer_jwt="..." \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Enable PKI secrets engine
bao secrets enable -tls-skip-verify -path=pki pki
```

---

### 4. SPIRE / SPIFFE

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Server Image** | `ghcr.io/spiffe/spire-server:1.10.0` | Same | SPIFFE official |
| **Agent Image** | `ghcr.io/spiffe/spire-agent:1.10.0` | Same | SPIFFE official |
| **Trust Domain** | `homelab.local` | Environment-specific | `pki-cloudlab.local` |
| **Node Attestor** | `k8s_psat` | Same | K8s Projected Service Account Token |
| **Workload Attestor** | `k8s`, `unix` | Same | Kubernetes + Unix |
| **Key Manager** | `disk` (server), `memory` (agent) | Same | Disk for server, memory for agent |
| **DataStore** | `sqlite3` | Same | Embedded database |
| **Notifier** | `k8sbundle` | Same | ConfigMap bundle distribution |
| **CSI Driver** | `spiffe/spiffe-csi-driver` | Same | Optional for direct injection |

**Environment-Specific Configuration:**
```yaml
# apps/spire/configmap-server.yaml
# Only trust_domain changes per environment
data:
  server.conf: |
    server {
      bind_address = "0.0.0.0"
      bind_port = "8081"
      trust_domain = "pki-cloudlab.local"  # <-- per environment
      data_dir = "/run/spire/data"
      log_level = "DEBUG"
      ca_key_type = "ec-p256"
      ca_subject = {
        country = ["US"]
        organization = ["Homelab"]
        common_name = "pki-cloudlab.local"
      }
    }
```

**Cloud-Neutral Components:**
- StatefulSet for server (same)
- DaemonSet for agent (same)
- ConfigMaps (same structure, different trust domain)
- RBAC (same)
- NetworkPolicies (same)
- ServiceAccount tokens (same)

---

### 5. RabbitMQ

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Image** | `rabbitmq:4.1.3-management` | Same | Official image |
| **Management** | Enabled (port 15672) | Same | Web UI |
| **AMQP** | Port 5672 | Same | Standard protocol |
| **Storage** | Ephemeral (no PVC) | Same | State recreatable |
| **Replicas** | 1 | 1 | Single instance |
| **Credentials** | Default `guest/guest` | Configured | Via ConfigMap/Secret |

**Cloud-Neutral Manifest:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rabbitmq
  namespace: rabbitmq
spec:
  serviceName: rabbitmq
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:4.1.3-management
        ports:
        - containerPort: 5672
          name: amqp
        - containerPort: 15672
          name: management
        env:
        - name: RABBITMQ_DEFAULT_USER
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: username
        - name: RABBITMQ_DEFAULT_PASS
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: password
```

---

### 6. cert-api (Custom Application)

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Image** | `10.42.0.88:5000/cert-api:latest` | Registry-based | Build once, deploy everywhere |
| **Framework** | FastAPI | Same | Python 3.11+ |
| **Replicas** | 2 | 2-4 | Horizontal scaling |
| **Service** | ClusterIP (port 8000) | Same | Internal API |
| **Auth** | SPIFFE mTLS + OpenBao | Same | Identity-based |
| **Database** | PostgreSQL (pki namespace) | Same | Same schema |
| **Queue** | RabbitMQ | Same | AMQP protocol |

**Cloud-Neutral Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-api
  namespace: pki
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cert-api
  template:
    metadata:
      labels:
        app: cert-api
    spec:
      serviceAccountName: cert-api
      containers:
      - name: api
        image: registry/cert-api:latest  # <-- registry URL per environment
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: pki-database-credentials
              key: url
        - name: RABBITMQ_URL
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: url
        - name: OPENBAO_ADDR
          value: "https://openbao.openbao.svc:8200"
        - name: SPIFFE_SOCKET_PATH
          value: "/spiffe-socket/agent.sock"
        volumeMounts:
        - name: spiffe-socket
          mountPath: /spiffe-socket
      volumes:
      - name: spiffe-socket
        csi:
          driver: "csi.spiffe.io"
          readOnly: true
```

---

### 7. cert-worker (Custom Application)

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Image** | `10.42.0.88:5000/cert-worker:latest` | Registry-based | Build once, deploy everywhere |
| **Type** | Batch consumer | Same | RabbitMQ consumer |
| **Replicas** | 1 | 1-3 | Scale with queue depth |
| **Queue** | RabbitMQ | Same | AMQP protocol |
| **CA Client** | ca-service | Same | Internal API |
| **Auth** | SPIFFE mTLS + OpenBao | Same | Identity-based |

**Cloud-Neutral Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-worker
  namespace: pki
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cert-worker
  template:
    metadata:
      labels:
        app: cert-worker
    spec:
      serviceAccountName: cert-worker
      containers:
      - name: worker
        image: registry/cert-worker:latest
        env:
        - name: RABBITMQ_URL
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: url
        - name: CA_SERVICE_URL
          value: "http://ca-service.pki.svc:8000"
        - name: OPENBAO_ADDR
          value: "https://openbao.openbao.svc:8200"
        - name: SPIFFE_SOCKET_PATH
          value: "/spiffe-socket/agent.sock"
        volumeMounts:
        - name: spiffe-socket
          mountPath: /spiffe-socket
      volumes:
      - name: spiffe-socket
        csi:
          driver: "csi.spiffe.io"
          readOnly: true
```

---

### 8. ca-service (CA Abstraction Layer)

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Image** | `10.42.0.88:5000/ca-service:latest` | Registry-based | Build once, deploy everywhere |
| **Purpose** | Abstract EJBCA operations | Same | Protocol adapter |
| **Protocols** | EST, ACME, CMP, REST | Same | Multiple enrollment |
| **Replicas** | 2 | 2-4 | Stateless, horizontally scalable |
| **Service** | ClusterIP (port 8000) | Same | Internal API |
| **Auth** | SPIFFE mTLS | Same | Workload identity |

**Cloud-Neutral Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ca-service
  namespace: pki
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ca-service
  template:
    metadata:
      labels:
        app: ca-service
    spec:
      serviceAccountName: ca-service
      containers:
      - name: service
        image: registry/ca-service:latest
        ports:
        - containerPort: 8000
        env:
        - name: EJBCA_URL
          value: "https://ejbca.ejbca.svc"
        - name: EJBCA_CREDENTIALS
          valueFrom:
            secretKeyRef:
              name: ejbca-api-credentials
              key: p12
        - name: SPIFFE_SOCKET_PATH
          value: "/spiffe-socket/agent.sock"
        volumeMounts:
        - name: spiffe-socket
          mountPath: /spiffe-socket
      volumes:
      - name: spiffe-socket
        csi:
          driver: "csi.spiffe.io"
          readOnly: true
```

---

### 9. cert-manager

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Chart** | `jetstack/cert-manager` `v1.21.1` | Same | Pin version |
| **CRDs** | Enabled | Same | Manage CRDs |
| **Replicas** | 1 | 1 | Single instance |
| **Prometheus** | Disabled | Same | Simplify |
| **Issuer** | Self-signed ClusterIssuer | Same | Bootstrap issuer |

**Cloud-Neutral Manifest:**
```yaml
# apps/cert-manager/values.yaml
crds:
  enabled: true
replicaCount: 1
resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
webhook:
  replicaCount: 1
cainjector:
  replicaCount: 1
prometheus:
  enabled: false
```

---

### 10. Prometheus / Grafana

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Chart** | `kube-prometheus-stack` `88.5.4` | Same | Pin version |
| **Prometheus** | Enabled | Same | Metrics collection |
| **Grafana** | Enabled | Same | Dashboards |
| **Alertmanager** | Enabled | Same | Alerting |
| **Node Exporter** | Enabled | Same | Host metrics |
| **ServiceMonitors** | 13 active | Same | Auto-discovery |
| **PrometheusRules** | 35 groups | Same | Alert rules |
| **Storage** | `local-path` (20Gi) | Cloud CSI | Environment-specific |

**Cloud-Neutral Manifest:**
```yaml
# Monitoring via kube-prometheus-stack Helm chart
# Values override per environment for storage class only
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path  # <-- overlay per environment
          resources:
            requests:
              storage: 20Gi
```

---

### 11. Container Registry

| Attribute | Local Homelab | Cloud-Neutral Design | Notes |
|-----------|---------------|----------------------|-------|
| **Image** | `registry:2.8.3` | Same | Docker Distribution |
| **Service** | NodePort (30500) | Same | Internal access |
| **Storage** | `local-path` (50Gi) | Cloud CSI | Environment-specific |
| **Auth** | None (in-cluster) | Same | Network policy protected |

**Cloud-Neutral Manifest:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: registry:2.8.3
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: data
          mountPath: /var/lib/registry
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: registry-data
```

---

## Provider-Specific Integration Points

### What Changes Per Environment

| Component | What Changes | How |
|-----------|--------------|-----|
| **Storage Class** | Name | `local-path` → `managed-csi` / `gp2` |
| **LoadBalancer** | IP assignment | Cloud provider assigns |
| **Trust Domain** | SPIFFE domain | `homelab.local` → `pki-azure.local` / `pki-aws.local` |
| **Registry URL** | Image prefix | `10.42.0.88:5000` → `registry.azurecr.io` / `account.dkr.ecr.region.amazonaws.com` |
| **Node Labels** | Topology | Cloud provider adds region/zone labels |
| **External DNS** | Name resolution | Cloud DNS vs. local DNS |

### What Stays Identical

| Component | Why Identical |
|-----------|---------------|
| **Container Images** | Same registries, same versions |
| **Kubernetes Manifests** | Same API, same resources |
| **Helm Values** | Same charts, same configurations |
| **Application Code** | Same containers, same behavior |
| **Network Policies** | Same CIDRs, same rules |
| **RBAC** | Same roles, same bindings |
| **Service Accounts** | Same names, same permissions |
| **ConfigMaps** | Same data, same structure |
| **Secrets** | Same keys, same purposes |
| **Argo CD Applications** | Same Git repo, same paths |

---

## Kustomize Overlay Strategy

### Base + Overlays Pattern

```
apps/
├── base/                          # Cloud-neutral base manifests
│   ├── ejbca/
│   ├── postgres/
│   ├── openbao/
│   ├── spire/
│   ├── rabbitmq/
│   ├── pki/
│   ├── cert-manager/
│   └── monitoring/
│
└── overlays/
    ├── homelab/                   # Local environment patches
    │   ├── kustomization.yaml
    │   ├── storage-class-patch.yaml
    │   └── trust-domain-patch.yaml
    │
    ├── azure/                     # Azure environment patches
    │   ├── kustomization.yaml
    │   ├── storage-class-patch.yaml
    │   └── trust-domain-patch.yaml
    │
    └── aws/                       # AWS environment patches
        ├── kustomization.yaml
        ├── storage-class-patch.yaml
        └── trust-domain-patch.yaml
```

### Example Overlay Patch

```yaml
# overlays/azure/storage-class-patch.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-postgresql
  namespace: ejbca
spec:
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: managed-csi  # Azure Disk CSI
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: openbao
  namespace: openbao
spec:
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: managed-csi  # Azure Disk CSI
```

---

## Container Image Strategy

### Image Sources

| Image | Source | Versioning | Multi-arch |
|-------|--------|------------|------------|
| `keyfactor/ejbca-ce` | Docker Hub / Keyfactor OCI | `9.3.7` | amd64 |
| `bitnami/postgresql` | Docker Hub | `18.4.0` | amd64, arm64 |
| `openbao` | Docker Hub / GHCR | `2.6.2` | amd64, arm64 |
| `spire-server` | GHCR (SPIFFE) | `1.10.0` | amd64, arm64 |
| `spire-agent` | GHCR (SPIFFE) | `1.10.0` | amd64, arm64 |
| `rabbitmq` | Docker Hub | `4.1.3-management` | amd64, arm64 |
| `cert-api` | Local registry | `latest` → semver | amd64 |
| `cert-worker` | Local registry | `latest` → semver | amd64 |
| `ca-service` | Local registry | `latest` → semver | amd64 |
| `cert-manager` | Quay.io | `v1.21.1` | amd64, arm64 |
| `registry` | Docker Hub | `2.8.3` | amd64, arm64 |

### Registry Strategy

| Environment | Registry | Authentication |
|-------------|----------|----------------|
| Homelab | In-cluster (`registry:5000`) | None (network policy) |
| Azure | Azure Container Registry (future) | Managed Identity |
| AWS | Amazon ECR (future) | IAM Instance Profile |

---

## Configuration Management

### ConfigMap Strategy

| ConfigMap | Content | Environment-Specific |
|-----------|---------|---------------------|
| `spire-server` | SPIRE server config | Trust domain only |
| `spire-agent` | SPIRE agent config | Server address only |
| `spire-bundle` | Trust bundle | Auto-generated |
| `ejbca-nginx-config` | Nginx config | Same |

### Secret Strategy

| Secret | Content | Source |
|--------|---------|--------|
| `postgres-postgresql` | DB passwords | Helm auto-generated |
| `ejbca-db-credentials` | EJBCA DB creds | Referenced from postgres secret |
| `pki-database-credentials` | PKI app DB creds | Sealed Secret / External Secrets |
| `openbao-server-tls` | OpenBao TLS | cert-manager |
| `rabbitmq-credentials` | RabbitMQ creds | Sealed Secret / External Secrets |
| `ejbca-api-credentials` | EJBCA API p12 | Sealed Secret / External Secrets |

---

## Migration Path from Homelab to Cloud

### Step 1: Export CA Certificates (Public Only)

```bash
# Export Root CA certificate (public)
kubectl exec -n ejbca ejbca-ejbca-ce-0 -- \
  ejbca.sh ca getcacert --caname LabRootCA -f /tmp/root.crt

# Export Issuing CA certificate (public)
kubectl exec -n ejbca ejbca-ejbca-ce-0 -- \
  ejbca.sh ca getcacert --caname LabIssuingCA -f /tmp/issuing.crt
```

### Step 2: Export EJBCA Configuration

```bash
# Export certificate profiles
kubectl cp ejbca/ejbca-ejbca-ce-0:/opt/ejbca/conf/certprofiles ./certprofiles

# Export end entity profiles
kubectl cp ejbca/ejbca-ejbca-ce-0:/opt/ejbca/conf/eeprofiles ./eeprofiles
```

### Step 3: Reconstruct in Cloud

1. Deploy EJBCA with same chart version
2. Import CA certificates (create CAs with existing keys — requires key export)
3. Recreate certificate profiles
4. Recreate end entity profiles
5. Configure same enrollment protocols

### Step 4: Verify Trust Chain

```bash
# Verify certificate chain in cloud
openssl verify -CAfile root.crt -untrusted issuing.crt test.crt
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-02 | PKI Platform Engineer | Initial component mapping |
