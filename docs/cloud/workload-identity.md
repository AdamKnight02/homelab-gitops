# Workload Identity Design

## Overview

This document defines the workload identity architecture for the Machine Identity Platform, covering SPIFFE/SPIRE, OpenBao authentication, Kubernetes ServiceAccounts, and cloud-native identity integration.

The design is **cloud-neutral** with documented integration points for Azure Managed Identity and AWS IAM.

---

## Identity Systems Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         IDENTITY SYSTEMS LANDSCAPE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   SPIFFE /      │  │   OpenBao       │  │   Kubernetes    │             │
│  │   SPIRE         │  │   (Secrets)     │  │   ServiceAccount│             │
│  │                 │  │                 │  │                 │             │
│  │  Workload       │  │  Secret         │  │  Pod Identity   │             │
│  │  Identity       │  │  Management     │  │  (K8s-native)   │             │
│  │                 │  │                 │  │                 │             │
│  │  • SVIDs        │  │  • KV Store     │  │  • RBAC         │             │
│  │  • mTLS         │  │  • PKI Engine   │  │  • NetworkPolicy│             │
│  │  • Attestation  │  │  • Transit      │  │  • Admission    │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   Azure         │  │   AWS           │  │   cert-manager  │             │
│  │   Managed       │  │   IAM           │  │                 │             │
│  │   Identity      │  │                 │  │  Certificate    │             │
│  │                 │  │  • Instance     │  │  Automation     │             │
│  │  • VM Identity  │  │    Profiles     │  │                 │             │
│  │  • AKS Pod      │  │  • IAM Roles    │  │  • TLS Certs    │             │
│  │    Identity     │  │  • STS          │  │  • Auto-renew   │             │
│  │  • Key Vault    │  │                 │  │                 │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## SPIFFE / SPIRE Architecture

### Trust Domain Design

| Environment | Trust Domain | Rationale |
|-------------|--------------|-----------|
| **Homelab** | `homelab.local` | Existing, well-known |
| **Azure** | `pki-azure.local` | Cloud-specific, prevents collisions |
| **AWS** | `pki-aws.local` | Cloud-specific, prevents collisions |
| **Future: Federation** | `pki-cloudlab.local` | Cross-environment federation |

### SPIFFE ID Scheme

```
spiffe://{trust_domain}/ns/{namespace}/sa/{service_account}
```

**Standard Workload IDs:**

| Workload | Namespace | ServiceAccount | SPIFFE ID (Homelab) |
|----------|-----------|----------------|---------------------|
| cert-api | pki | cert-api | `spiffe://homelab.local/ns/pki/sa/cert-api` |
| cert-worker | pki | cert-worker | `spiffe://homelab.local/ns/pki/sa/cert-worker` |
| ca-service | pki | ca-service | `spiffe://homelab.local/ns/pki/sa/ca-service` |
| EJBCA | ejbca | ejbca | `spiffe://homelab.local/ns/ejbca/sa/ejbca` |
| OpenBao | openbao | openbao | `spiffe://homelab.local/ns/openbao/sa/openbao` |
| PostgreSQL | ejbca | postgres | `spiffe://homelab.local/ns/ejbca/sa/postgres` |
| RabbitMQ | rabbitmq | rabbitmq | `spiffe://homelab.local/ns/rabbitmq/sa/rabbitmq` |
| SPIRE Server | spire | spire-server | `spiffe://homelab.local/ns/spire/sa/spire-server` |
| SPIRE Agent | spire | spire-agent | `spiffe://homelab.local/ns/spire/sa/spire-agent` |

**Application Workload IDs:**

| Application | Namespace | ServiceAccount | SPIFFE ID |
|-------------|-----------|----------------|-----------|
| Generic web app | apps | web-server | `spiffe://homelab.local/ns/apps/sa/web-server` |
| API gateway | ingress | gateway | `spiffe://homelab.local/ns/ingress/sa/gateway` |
| Monitoring | monitoring | prometheus | `spiffe://homelab.local/ns/monitoring/sa/prometheus` |

### SPIRE Server Configuration

```hcl
# server.conf
server {
  bind_address = "0.0.0.0"
  bind_port = "8081"
  trust_domain = "pki-cloudlab.local"
  data_dir = "/run/spire/data"
  log_level = "DEBUG"
  ca_key_type = "ec-p256"
  
  ca_subject = {
    country = ["US"]
    organization = ["Homelab"]
    common_name = "pki-cloudlab.local"
  }
}

plugins {
  DataStore "sql" {
    plugin_data {
      database_type = "sqlite3"
      connection_string = "/run/spire/data/datastore.sqlite3"
    }
  }
  
  NodeAttestor "k8s_psat" {
    plugin_data {
      clusters = {
        "k3s" = {
          use_token_review_api_validation = true
          service_account_allow_list = ["spire:spire-agent"]
          kube_config_file = ""
        }
      }
    }
  }
  
  KeyManager "disk" {
    plugin_data {
      keys_path = "/run/spire/data/keys.json"
    }
  }
  
  Notifier "k8sbundle" {
    plugin_data {
      namespace = "spire"
      config_map = "spire-bundle"
      config_map_key = "bundle.crt"
    }
  }
}
```

### SPIRE Agent Configuration

```hcl
# agent.conf
agent {
  data_dir = "/run/spire"
  log_level = "DEBUG"
  server_address = "spire-server"
  server_port = "8081"
  socket_path = "/run/spire/sockets/agent.sock"
  trust_domain = "pki-cloudlab.local"
  insecure_bootstrap = true
}

plugins {
  NodeAttestor "k8s_psat" {
    plugin_data {
      cluster = "k3s"
      token_path = "/var/run/secrets/tokens/spire-agent"
    }
  }
  
  KeyManager "memory" {
    plugin_data {}
  }
  
  WorkloadAttestor "k8s" {
    plugin_data {
      skip_kubelet_verification = true
    }
  }
  
  WorkloadAttestor "unix" {
    plugin_data {}
  }
}
```

### ClusterSPIFFEID (Automatic Workload Registration)

```yaml
apiVersion: spire.spiffe.io/v1alpha1
kind: ClusterSPIFFEID
metadata:
  name: default
spec:
  spiffeIDTemplate: "spiffe://{{ .TrustDomain }}/ns/{{ .PodMeta.Namespace }}/sa/{{ .PodSpec.ServiceAccountName }}"
  podSelector:
    matchLabels:
      spiffe.io/spire-managed-identity: "true"
  workloadSelectorTemplates:
    - "k8s:ns:{{ .PodMeta.Namespace }}"
    - "k8s:sa:{{ .PodSpec.ServiceAccountName }}"
```

### SVID Distribution

SPIRE distributes SVIDs (SPIFFE Verifiable Identity Documents) to workloads:

```
┌─────────────────────────────────────────────────────────────┐
│                      SVID LIFECYCLE                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. WORKLOAD STARTS                                          │
│     └── Pod created with ServiceAccount                      │
│                                                              │
│  2. NODE ATTESTATION                                         │
│     └── SPIRE Agent proves node identity via k8s_psat        │
│                                                              │
│  3. WORKLOAD ATTESTATION                                     │
│     └── SPIRE Agent verifies pod via K8s/Unix attestors      │
│                                                              │
│  4. SVID ISSUANCE                                            │
│     └── SPIRE Server issues X.509 SVID                       │
│         • Subject: SPIFFE ID as URI SAN                      │
│         • Issuer: SPIRE CA                                   │
│         • Lifetime: ~1 hour (short-lived)                    │
│                                                              │
│  5. SVID DELIVERY                                            │
│     └── SPIRE Agent delivers to workload via:                │
│         • CSI Driver (recommended)                           │
│         • Secret (legacy)                                    │
│         • Unix socket (direct)                               │
│                                                              │
│  6. SVID RENEWAL                                             │
│     └── Automatic before expiry (~50% lifetime)              │
│                                                              │
│  7. SVID REVOCATION                                          │
│     └── On workload termination or policy violation          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## OpenBao Authentication

### Auth Methods

| Method | Path | Purpose | Status |
|--------|------|---------|--------|
| **Kubernetes** | `auth/kubernetes/` | K8s ServiceAccount auth | ✅ Active |
| **SPIFFE** | `auth/spire-cert/` | SPIRE SVID auth | ✅ Active |
| **mTLS** | `auth/spire-mtls/` | SPIRE mTLS auth | ✅ Active |
| **Token** | `auth/token/` | Direct token auth | ✅ Active |

### Kubernetes Auth Configuration

```bash
# Enable Kubernetes auth
bao auth enable -tls-skip-verify kubernetes

# Configure K8s auth
bao write -tls-skip-verify auth/kubernetes/config \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  issuer="https://kubernetes.default.svc.cluster.local"

# Create role for cert-api
bao write -tls-skip-verify auth/kubernetes/role/cert-api \
  bound_service_account_names=cert-api \
  bound_service_account_namespaces=pki \
  policies=pki-api-policy \
  ttl=1h
```

### SPIFFE Auth Configuration

```bash
# Enable cert auth for SPIFFE
bao auth enable -tls-skip-verify -path=spire-cert cert

# Configure SPIFFE auth
bao write -tls-skip-verify auth/spire-cert/config \
  ocsp_disable=true

# Create role for cert-api SPIFFE ID
bao write -tls-skip-verify auth/spire-cert/roles/cert-api \
  allowed_uri_sans="spiffe://homelab.local/ns/pki/sa/cert-api" \
  allowed_organizational_units=["Homelab"] \
  policies=pki-api-policy \
  ttl=1h
```

### Policy Definitions

```hcl
# pki-api-policy.hcl
path "secret/data/pki/*" {
  capabilities = ["read", "list"]
}

path "pki/issue/*" {
  capabilities = ["create", "update"]
}

path "pki/roles/*" {
  capabilities = ["read", "list"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

```hcl
# pki-worker-policy.hcl
path "secret/data/pki/database" {
  capabilities = ["read"]
}

path "secret/data/rabbitmq/*" {
  capabilities = ["read"]
}

path "secret/data/ejbca/*" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

---

## Kubernetes ServiceAccount Integration

### ServiceAccount Design

| Namespace | ServiceAccount | Purpose | SPIFFE-enabled |
|-----------|---------------|---------|----------------|
| pki | cert-api | Certificate API | ✅ |
| pki | cert-worker | Certificate worker | ✅ |
| pki | ca-service | CA abstraction | ✅ |
| ejbca | ejbca | EJBCA application | ✅ |
| openbao | openbao | OpenBao server | ✅ |
| spire | spire-server | SPIRE server | ✅ |
| spire | spire-agent | SPIRE agent | ✅ |
| rabbitmq | rabbitmq | RabbitMQ | ✅ |

### ServiceAccount Example

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-api
  namespace: pki
  labels:
    spiffe.io/spire-managed-identity: "true"
automountServiceAccountToken: true
```

### RBAC for SPIRE

```yaml
# SPIRE Server RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: spire-server
rules:
- apiGroups: [""]
  resources: ["nodes","pods"]
  verbs: ["get","list","watch"]
- apiGroups: ["authentication.k8s.io"]
  resources: ["tokenreviews"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spire-server
roleRef:
  kind: ClusterRole
  name: spire-server
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: spire-server
  namespace: spire
```

---

## Cloud-Native Identity Integration

### Azure Managed Identity

```
┌─────────────────────────────────────────────────────────────┐
│                    AZURE INTEGRATION                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐         ┌─────────────┐                   │
│  │  Azure VM   │────────►│  System-    │                   │
│  │  (K3s node) │  IMDS   │  assigned   │                   │
│  │             │         │  Managed    │                   │
│  │             │         │  Identity   │                   │
│  └──────┬──────┘         └──────┬──────┘                   │
│         │                        │                          │
│         │                        │ Token                    │
│         ▼                        ▼                          │
│  ┌─────────────┐         ┌─────────────┐                   │
│  │   K3s       │         │  Azure      │                   │
│  │  (kubelet)  │         │  Key Vault  │                   │
│  │             │         │  (Secrets)  │                   │
│  └─────────────┘         └─────────────┘                   │
│                                                              │
│  ┌─────────────┐                                            │
│  │  Workload   │                                            │
│  │  (Pod)      │                                            │
│  │             │── SPIFFE ID ──► SPIRE ──► OpenBao         │
│  │             │                                            │
│  └─────────────┘                                            │
│                                                              │
│  IDENTITY CHAIN:                                             │
│  Azure Managed Identity ──► VM ──► K3s ──► Pod ──► SPIFFE  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Azure Integration Points:**

| Feature | Purpose | Implementation |
|---------|---------|----------------|
| System-assigned Managed Identity | VM identity | Enabled on Azure VM |
| Azure Key Vault | Secret storage | Future: OpenBao auto-unseal |
| Azure AD Workload Identity | Pod identity | Future: AKS alternative |

**Terraform (Documented Only):**
```hcl
# Azure VM with Managed Identity
resource "azurerm_linux_virtual_machine" "k3s" {
  name                = "k3s-node"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  
  identity {
    type = "SystemAssigned"
  }
  
  # ... other config
}

# Allow VM to read Key Vault
resource "azurerm_key_vault_access_policy" "k3s" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.k3s.identity[0].principal_id
  
  secret_permissions = ["Get", "List"]
  key_permissions    = ["Get", "List"]
}
```

### AWS IAM Integration

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS INTEGRATION                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐         ┌─────────────┐                   │
│  │  EC2        │────────►│  IAM        │                   │
│  │  (K3s node) │  IMDS   │  Instance   │                   │
│  │             │         │  Profile    │                   │
│  └──────┬──────┘         └──────┬──────┘                   │
│         │                        │                          │
│         │                        │ Credentials              │
│         ▼                        ▼                          │
│  ┌─────────────┐         ┌─────────────┐                   │
│  │   K3s       │         │  AWS        │                   │
│  │  (kubelet)  │         │  Secrets    │                   │
│  │             │         │  Manager    │                   │
│  └─────────────┘         └─────────────┘                   │
│                                                              │
│  ┌─────────────┐                                            │
│  │  Workload   │                                            │
│  │  (Pod)      │                                            │
│  │             │── SPIFFE ID ──► SPIRE ──► OpenBao         │
│  │             │                                            │
│  └─────────────┘                                            │
│                                                              │
│  IDENTITY CHAIN:                                             │
│  IAM Instance Profile ──► EC2 ──► K3s ──► Pod ──► SPIFFE   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**AWS Integration Points:**

| Feature | Purpose | Implementation |
|---------|---------|----------------|
| IAM Instance Profile | EC2 identity | Attached to EC2 instance |
| AWS KMS | Key storage | Future: OpenBao auto-unseal |
| AWS Secrets Manager | Secret storage | Future: External Secrets operator |
| IRSA (IAM Roles for Service Accounts) | Pod-level IAM | Future: EKS alternative |

**Terraform (Documented Only):**
```hcl
# IAM Role for EC2
resource "aws_iam_role" "k3s_node" {
  name = "k3s-node-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "k3s_node" {
  name = "k3s-node-profile"
  role = aws_iam_role.k3s_node.name
}

# Attach to EC2
resource "aws_instance" "k3s" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  
  iam_instance_profile = aws_iam_instance_profile.k3s_node.name
  
  # ... other config
}
```

---

## Identity Comparison Matrix

| Aspect | SPIFFE/SPIRE | Kubernetes SA | Azure MI | AWS IAM |
|--------|--------------|---------------|----------|---------|
| **Scope** | Cross-platform | K8s-only | Azure-only | AWS-only |
| **Format** | URI (SPIFFE ID) | JWT token | JWT token | Access key / STS |
| **Lifetime** | Short (hours) | Long (token expiry) | Managed | Managed |
| **Rotation** | Automatic | Manual | Automatic | Automatic |
| **mTLS** | Native | Via cert-manager | Via sidecar | Via sidecar |
| **Attestation** | Workload-based | Token-based | VM-based | Instance-based |
| **Federation** | Yes (SPIFFE) | No | No (AAD only) | No (STS only) |
| **Use Case** | Service mesh | K8s RBAC | Azure resources | AWS resources |

---

## Coexistence Strategy

### Layered Identity Model

```
┌─────────────────────────────────────────────────────────────┐
│                    LAYER 3: WORKLOAD                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  SPIFFE ID: spiffe://.../ns/pki/sa/cert-api         │   │
│  │  Purpose: Service-to-service mTLS authentication    │   │
│  │  Scope: Cross-platform, cross-cloud                 │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    LAYER 2: PLATFORM                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Kubernetes ServiceAccount: cert-api (ns: pki)      │   │
│  │  Purpose: K8s RBAC, pod identity, SPIRE attestation │   │
│  │  Scope: Kubernetes cluster                          │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    LAYER 1: INFRASTRUCTURE                   │
│  ┌────────────────────────┐  ┌────────────────────────┐   │
│  │  Azure:                │  │  AWS:                  │   │
│  │  Managed Identity      │  │  IAM Instance Profile  │   │
│  │  Purpose: Cloud        │  │  Purpose: Cloud        │   │
│  │  resource access       │  │  resource access       │   │
│  │  Scope: Azure          │  │  Scope: AWS            │   │
│  └────────────────────────┘  └────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### When to Use Each

| Scenario | Primary Identity | Secondary | Notes |
|----------|-----------------|-----------|-------|
| Pod-to-pod mTLS | SPIFFE | K8s SA | SPIRE provides SVIDs |
| K8s API access | K8s SA | — | Native K8s RBAC |
| Azure Key Vault | Azure MI | SPIFFE | MI for cloud auth |
| AWS S3 access | AWS IAM | SPIFFE | IAM for cloud auth |
| OpenBao auth | SPIFFE | K8s SA | Both methods enabled |
| RabbitMQ auth | SPIFFE | Username | mTLS + user/pass |
| EJBCA enrollment | SPIFFE | Client cert | mTLS to CA |

---

## Security Boundaries

### Network Policies by Identity

```yaml
# Allow cert-api to talk to RabbitMQ based on SPIFFE ID
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: rabbitmq-allow-cert-api
  namespace: rabbitmq
spec:
  podSelector:
    matchLabels:
      app: rabbitmq
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: pki
      podSelector:
        matchLabels:
          app: cert-api
    ports:
    - protocol: TCP
      port: 5672
```

### OpenBao Policy by SPIFFE ID

```hcl
# Allow only cert-api SPIFFE ID to issue certificates
path "pki/issue/internal" {
  capabilities = ["create", "update"]
  allowed_uri_sans = ["spiffe://homelab.local/ns/pki/sa/cert-api"]
}
```

---

## Federation (Future)

### Cross-Environment Trust

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   Homelab       │         │     Azure       │         │      AWS        │
│                 │         │                 │         │                 │
│  Trust Domain:  │◄───────►│  Trust Domain:  │◄───────►│  Trust Domain:  │
│  homelab.local  │  Bundle │  pki-azure.local│  Bundle │  pki-aws.local  │
│                 │ Exchange│                 │ Exchange│                 │
│  SPIRE Server   │         │  SPIRE Server   │         │  SPIRE Server   │
│                 │         │                 │         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

**Federation Configuration:**
```hcl
# On homelab SPIRE server
server {
  # ...
  federation {
    bundle_endpoint {
      address = "0.0.0.0"
      port = 8443
    }
    
    federates_with "pki-azure.local" {
      bundle_endpoint_url = "https://spire-azure.example.com:8443"
    }
    
    federates_with "pki-aws.local" {
      bundle_endpoint_url = "https://spire-aws.example.com:8443"
    }
  }
}
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-02 | PKI Platform Engineer | Initial workload identity design |
