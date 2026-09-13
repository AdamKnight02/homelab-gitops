# Multi-Cloud PKI Lab — Crash Course

## Table of Contents

1. [Terraform Fundamentals](#terraform)
2. [AWS Concepts](#aws)
3. [Azure Concepts](#azure)
4. [Kubernetes & K3s](#kubernetes)
5. [PKI Fundamentals](#pki)
6. [Identity & SPIFFE](#identity)
7. [GitOps & Argo CD](#gitops)

---

## Terraform

### What is Terraform?

Terraform is an Infrastructure-as-Code (IaC) tool that lets you define cloud resources in declarative configuration files.

### Key Concepts

#### Providers

Providers are plugins that Terraform uses to interact with cloud APIs.

```hcl
# AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Azure Provider
provider "azurerm" {
  features {}
}
```

**In this repo**: See `infra/terraform/azure/providers.tf` and `infra/terraform/aws/providers.tf`

#### Resources

Resources are the building blocks of your infrastructure.

```hcl
# AWS EC2 Instance
resource "aws_instance" "main" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}

# Azure VM
resource "azurerm_linux_virtual_machine" "main" {
  name     = "pki-lab-vm"
  size     = "Standard_B1s"
  location = "eastus"
}
```

**In this repo**: See `infra/terraform/aws/main.tf` and `infra/terraform/azure/main.tf`

#### Variables

Variables make your configuration reusable.

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

**In this repo**: See `infra/terraform/aws/variables.tf` and `infra/terraform/azure/variables.tf`

#### Locals

Locals are computed values used within a module.

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
```

**In this repo**: See `infra/terraform/aws/locals.tf` and `infra/terraform/azure/locals.tf`

#### Outputs

Outputs expose information about your infrastructure.

```hcl
output "instance_public_ip" {
  value = aws_instance.main.public_ip
}
```

**In this repo**: See `infra/terraform/aws/outputs.tf` and `infra/terraform/azure/outputs.tf`

#### State

Terraform tracks resources in a state file.

```
terraform.tfstate  # NEVER commit this!
```

**In this repo**: `.gitignore` excludes all state files

#### Plan

Preview changes before applying:

```bash
terraform plan
```

#### Apply

Create or update resources:

```bash
terraform apply
```

**Note**: Azure is PLAN-ONLY. AWS is PLAN-ONLY by default.

#### Destroy

Remove all resources:

```bash
terraform destroy
```

---

## AWS

### AWS Account

An AWS account is the top-level container for all your AWS resources. Account ID: `962500057493`

### IAM

Identity and Access Management controls who can do what.

- **User**: AdamKnight (with AdministratorAccess)
- **Role**: Assumed by services (EC2, Lambda)
- **Policy**: JSON document defining permissions

### VPC

Virtual Private Cloud — your isolated network in AWS.

```
VPC (10.1.0.0/16)
├── Subnet (10.1.1.0/24)
├── Internet Gateway
└── Route Table
```

**In this repo**: `infra/terraform/aws/main.tf` defines VPC resources

### Security Group

Stateful firewall for EC2 instances.

```
Ingress: SSH (22), HTTP (80), HTTPS (443), K3s (6443)
Egress: All traffic
```

### EC2

Elastic Compute Cloud — virtual machines.

- **t3.micro**: 2 vCPU, 1 GB RAM (Free Tier)
- **EBS**: Elastic Block Store (disk)

**In this repo**: `infra/terraform/aws/main.tf` defines EC2 instance

### Why Avoid Certain Services?

| Service | Cost | Why Avoided |
|---------|------|-------------|
| EKS | $75/month | Expensive, not needed |
| RDS | $15/month | PostgreSQL runs in K3s |
| NAT Gateway | $32/month | Public subnet sufficient |
| ALB | $20/month | NodePort is free |

---

## Azure

### Tenant

An Azure AD tenant is your organization's identity service.

### Subscription

A subscription is a billing boundary for Azure resources.

- **Subscription**: "Azure subscription 1"
- **Type**: PAY-AS-YOU-GO
- **No free credits**

### Resource Group

A container for related resources.

```hcl
resource "azurerm_resource_group" "main" {
  name     = "pki-lab-azure-rg"
  location = "eastus"
}
```

### VNet

Virtual Network — isolated network in Azure.

```
VNet (10.0.0.0/16)
├── Subnet (10.0.1.0/24)
└── NSG
```

### NSG

Network Security Group — firewall rules.

```
Allow SSH (22)
Allow HTTP (80)
Allow HTTPS (443)
Allow K3s API (6443)
Deny all other inbound
```

### VM

Virtual Machine — compute resource.

- **Standard_B1s**: 1 vCPU, 1 GB RAM (~$13/month)
- **Managed Disk**: 30 GB Standard SSD

### Why PLAN-ONLY?

- PAY-AS-YOU-GO subscription
- No free credits available
- ~$18/month real cost
- Learning value from plan alone

---

## Kubernetes

### K3s

Lightweight Kubernetes distribution.

```bash
# Install K3s
curl -sfL https://get.k3s.io | sh -

# Check nodes
kubectl get nodes
```

**Why K3s?**
- Single binary
- Low resource usage
- Same Kubernetes API
- Runs on VMs, not just cloud K8s

### Architecture

```
VM (Azure/AWS)
└── K3s
    ├── kube-apiserver
    ├── kube-scheduler
    ├── kube-controller-manager
    └── containerd
```

### Argo CD

GitOps controller for Kubernetes.

```
Argo CD
├── Application Controller
├── Repo Server
├── API Server
└── Dex (SSO)
```

**In this repo**: `apps/cloud-apps.yaml` defines ApplicationSet

### GitOps Flow

```
Git Repository
    │
    ├── apps/base/           # Shared configs
    ├── apps/overlays/       # Environment patches
    │   ├── homelab/
    │   ├── azure/
    │   └── aws/
    │
    └── Argo CD pulls and applies
```

---

## PKI

### Root CA

The top-level certificate authority. Self-signed, highly protected.

### Issuing CA

Intermediate CA that issues end-entity certificates.

### EJBCA

Enterprise Java Beans Certificate Authority — open-source PKI software.

**Components**:
- Certificate Profiles
- End Entity Profiles
- Crypto Tokens
- OCSP Responder
- CRL Distribution

### Certificate Lifecycle

```
Request → Validate → Issue → Store → Monitor → Renew/Revoke → Expire
```

### Certificate API

REST API for certificate operations.

```
POST /v1/certificates      # Request cert
GET  /v1/certificates/{id} # Get status
POST /v1/certificates/{id}/renew
POST /v1/certificates/{id}/revoke
```

### Why EJBCA?

- Open source
- Feature-rich
- Industry-proven
- Same across all environments

---

## Identity

### Kubernetes ServiceAccount

In-cluster identity for pods.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-api
  namespace: pki
```

### SPIFFE

Secure Production Identity Framework for Everyone.

```
SPIFFE ID: spiffe://trust-domain/ns/namespace/sa/serviceaccount

Example: spiffe://homelab.local/ns/pki/sa/cert-api
```

### SPIRE

SPIFFE Runtime Environment — issues and validates SVIDs.

**Components**:
- SPIRE Server
- SPIRE Agent
- CSI Driver
- OIDC Discovery Provider

### OpenBao

Open-source secrets management (HashiCorp Vault fork).

**Features**:
- KV secrets engine
- PKI secrets engine
- Kubernetes auth method
- Dynamic secrets

### mTLS

Mutual TLS — both client and server authenticate.

```
Client → presents certificate → Server verifies
Server → presents certificate → Client verifies
```

### Identity Comparison

| System | Scope | Use Case |
|--------|-------|----------|
| Kubernetes SA | Cluster | In-cluster auth |
| SPIFFE | Cross-cluster | Workload identity |
| OpenBao | Platform | Secrets management |
| AWS IAM | AWS | Cloud resource access |
| Azure RBAC | Azure | Cloud resource access |

---

## GitOps

### What is GitOps?

Using Git as the single source of truth for infrastructure and applications.

### Argo CD Application

Defines what to deploy and where.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    repoURL: https://github.com/AdamKnight02/homelab-gitops.git
    path: apps/pki
  destination:
    server: https://kubernetes.default.svc
    namespace: pki
```

### ApplicationSet

Deploys to multiple environments.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
spec:
  generators:
    - list:
        elements:
          - name: azure
          - name: aws
```

**In this repo**: `apps/cloud-apps.yaml`

### Kustomize

Kubernetes native configuration management.

```yaml
# Base
resources:
  - deployment.yaml
  - service.yaml

# Overlay (azure)
patches:
  - target:
      kind: Deployment
      name: cert-api
    patch: |
      - op: replace
        path: /spec/replicas
        value: 1
```

**In this repo**: `apps/overlays/azure/kustomization.yaml`

---

## Summary

This lab demonstrates:

1. **Terraform** for cloud infrastructure
2. **K3s** for lightweight Kubernetes
3. **Argo CD** for GitOps
4. **EJBCA** for PKI
5. **SPIFFE/SPIRE** for workload identity
6. **OpenBao** for secrets
7. **Cloud portability** with minimal changes

The architecture is:
- **Portable**: Same components across clouds
- **Affordable**: Minimal cloud costs
- **Educational**: Clear separation of concerns
- **Safe**: Plan-only by default
