# Workload Identity Design

> **Status**: Cloud-neutral SPIFFE/SPIRE architecture for multi-cloud PKI lab

## Identity Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  cert-api   │  │ cert-worker │  │   ca-service        │ │
│  │  (SPIFFE)   │  │  (SPIFFE)   │  │    (SPIFFE)         │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                    │            │
│  ┌──────┴────────────────┴────────────────────┴──────────┐ │
│  │              SPIRE Agent (DaemonSet)                   │ │
│  │         Provides SVIDs to workloads                    │ │
│  └─────────────────────────┬──────────────────────────────┘ │
│                            │                                │
│  ┌─────────────────────────┴──────────────────────────────┐ │
│  │              SPIRE Server (StatefulSet)                │ │
│  │         Issues SVIDs, manages trust                    │ │
│  └─────────────────────────┬──────────────────────────────┘ │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │   Trust Domain   │
                    │  pki-cloudlab    │
                    └─────────────────┘
```

## SPIFFE IDs

### Local Homelab

```
spiffe://homelab.local/ns/pki/sa/cert-api
spiffe://homelab.local/ns/pki/sa/cert-worker
spiffe://homelab.local/ns/pki/sa/ca-service
spiffe://homelab.local/ns/ejbca/sa/ejbca
spiffe://homelab.local/ns/openbao/sa/openbao
```

### Azure

```
spiffe://azure.pki-cloudlab.local/ns/pki/sa/cert-api
spiffe://azure.pki-cloudlab.local/ns/pki/sa/cert-worker
spiffe://azure.pki-cloudlab.local/ns/pki/sa/ca-service
```

### AWS

```
spiffe://aws.pki-cloudlab.local/ns/pki/sa/cert-api
spiffe://aws.pki-cloudlab.local/ns/pki/sa/cert-worker
spiffe://aws.pki-cloudlab.local/ns/pki/sa/ca-service
```

## Cloud-Native Identity Integration

### AWS IAM Roles for Service Accounts (IRSA)

Not used in this lab to maintain portability. If needed:

```yaml
# Example IRSA annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/pki-role
```

### Azure Managed Identity

Not used in this lab to maintain portability. If needed:

```yaml
# Example pod-managed identity
apiVersion: v1
kind: Pod
metadata:
  labels:
    aadpodidbinding: pki-identity
```

### Why SPIFFE Instead of Cloud-Native Identity?

| Factor | SPIFFE | Cloud-Native |
|--------|--------|--------------|
| Portability | High (works everywhere) | Low (cloud-specific) |
| Standardization | Open standard | Vendor-specific |
| mTLS | Built-in | Requires additional setup |
| Cross-cluster | Yes | No |
| Learning Value | High | Medium |

## OpenBao Integration

### Authentication

```bash
# Kubernetes auth method
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create role for cert-api
vault write auth/kubernetes/role/cert-api \
  bound_service_account_names=cert-api \
  bound_service_account_namespaces=pki \
  policies=cert-api-policy \
  ttl=1h
```

### PKI Secrets Engine

```bash
# Enable PKI
vault secrets enable pki

# Configure CA
vault write pki/root/generate/internal \
  common_name="pki-cloudlab-ca" \
  ttl=8760h

# Create role
vault write pki/roles/pki-cloudlab \
  allowed_domains=pki-cloudlab.local \
  allow_subdomains=true \
  max_ttl=72h
```

## mTLS Between Services

### Certificate API → Certificate Worker

```yaml
# cert-api deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-api
spec:
  template:
    spec:
      containers:
      - name: cert-api
        image: cert-api:latest
        volumeMounts:
        - name: spiffe-socket
          mountPath: /spiffe-socket
      volumes:
      - name: spiffe-socket
        csi:
          driver: spiffe.csi.cert-manager.io
```

### Service-to-Service Authentication

```python
# Example: cert-api authenticating to cert-worker
import grpc
from spiffe import WorkloadApiClient

client = WorkloadApiClient(socket_path='/spiffe-socket/agent.sock')
svid = client.fetch_x509_svid()

credentials = grpc.ssl_channel_credentials(
    root_certificates=svid.trust_bundle,
    private_key=svid.private_key,
    certificate_chain=svid.certificate_chain
)

channel = grpc.secure_channel('cert-worker:8000', credentials)
```

## Trust Domain Design

### Hierarchical Trust

```
pki-cloudlab.local (root)
├── homelab.local (local cluster)
├── azure.pki-cloudlab.local (Azure cluster)
└── aws.pki-cloudlab.local (AWS cluster)
```

### Federation

```bash
# Configure trust domain federation
spire-server bundle show -id spiffe://homelab.local
spire-server bundle set -id spiffe://azure.pki-cloudlab.local -path azure-bundle.pem
spire-server bundle set -id spiffe://aws.pki-cloudlab.local -path aws-bundle.pem
```

## Implementation Notes

1. **SPIRE Server** runs as StatefulSet with persistent storage
2. **SPIRE Agent** runs as DaemonSet on all nodes
3. **CSI Driver** provides SVIDs to pods via volume mounts
4. **OIDC Discovery** enables external validation of SVIDs
5. **OpenBao** stores CA keys and issues certificates
6. **cert-manager** automates TLS certificate management
