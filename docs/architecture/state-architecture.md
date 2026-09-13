# Terraform State Architecture

## Overview

This document defines the state management strategy for the PKI Platform multi-cloud expansion. It covers backend configuration, state separation, locking, and migration patterns.

**Design Principles:**
- State is a security boundary — treat it as sensitive data
- Directory-based separation over workspace-based separation
- Remote state with locking for team collaboration
- Import-first migration for existing infrastructure
- Idempotency through deterministic naming and data sources

---

## Current State

The existing Terraform code uses **local state** with directory-based separation:

```
infra/terraform/
├── azure/          # Azure root module (local state)
│   ├── .terraform/ # Provider cache
│   └── terraform.tfstate (if applied)
├── aws/            # AWS root module (local state)
│   ├── .terraform/
│   └── terraform.tfstate (if applied)
└── modules/
    ├── shared/     # Shared variables, tags, versions
    ├── azure/      # Azure-specific modules (placeholder)
    └── aws/        # AWS-specific modules (placeholder)
```

**Current Limitations:**
- No remote state — single operator only
- No state locking — risk of concurrent modification
- No state encryption at rest
- No state versioning/backup
- No cross-environment state sharing

---

## Target State Architecture

### 1. Backend Architecture

#### Backend Selection Matrix

| Backend | Use Case | Pros | Cons |
|---------|----------|------|------|
| **S3 + DynamoDB** | AWS primary | Native AWS, versioning, locking | AWS-only |
| **Azure Blob + Lease** | Azure primary | Native Azure, locking | Azure-only |
| **Terraform Cloud** | Multi-cloud | Managed, RBAC, VCS integration | Cost, external dependency |
| **Consul** | On-prem/multi-cloud | Self-hosted, flexible | Operational overhead |
| **Kubernetes** | K8s-native | Uses existing cluster | Not for infrastructure provisioning |

#### Recommended: Multi-Backend Strategy

For a multi-cloud PKI platform, use **per-cloud backends** with a **shared configuration store**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    SHARED CONFIGURATION                          │
│              (Terraform Cloud / Consul / Git)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Global    │  │   Tier      │  │   Naming    │              │
│  │   Settings  │  │   Maps      │  │   Rules     │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  AWS Backend  │    │ Azure Backend │    │ Alibaba Backend│
│  S3 + DynamoDB│    │ Blob + Lease  │    │ OSS + TableStore│
│               │    │               │    │                │
│  State:       │    │  State:       │    │  State:        │
│  aws/*.tfstate│    │  azure/*.tfstate│  │  alibaba/*.tfstate│
└───────────────┘    └───────────────┘    └───────────────┘
```

**Rationale:**
- Each cloud's state stays in that cloud (data sovereignty, blast radius)
- Shared configuration via remote state data sources or external store
- No single point of failure across clouds
- Independent locking per cloud

---

### 2. State Separation Strategy

#### Directory-Based Separation (Current — Enhanced)

Maintain directory-based separation but add structure for customers/environments:

```
infra/terraform/
├── backends/                    # Backend configurations
│   ├── aws/
│   │   ├── backend.hcl         # S3 backend config
│   │   └── dynamodb.tf         # Lock table (optional, one-time)
│   ├── azure/
│   │   ├── backend.hcl         # Blob backend config
│   │   └── storage.tf          # Storage account (optional, one-time)
│   └── alibaba/
│       ├── backend.hcl         # OSS backend config
│       └── tablestore.tf       # Lock table (optional, one-time)
│
├── environments/                # Environment root modules
│   ├── _template/               # Template for new environments
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── lab/                     # Lab environment (current)
│   │   ├── aws/
│   │   │   ├── backend.tf      # Points to S3
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── terraform.tfvars
│   │   ├── azure/
│   │   │   ├── backend.tf      # Points to Blob
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── terraform.tfvars
│   │   └── alibaba/
│   │       ├── backend.tf      # Points to OSS
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── terraform.tfvars
│   │
│   ├── dev/                     # Development environment
│   │   ├── aws/
│   │   ├── azure/
│   │   └── alibaba/
│   │
│   ├── staging/                 # Staging environment
│   │   ├── aws/
│   │   ├── azure/
│   │   └── alibaba/
│   │
│   └── prod/                    # Production environment
│       ├── aws/
│       ├── azure/
│       └── alibaba/
│
├── customers/                   # Customer-specific overlays (optional)
│   ├── _template/
│   │   └── terraform.tfvars.example
│   ├── customer-a/
│   │   ├── lab/
│   │   │   └── terraform.tfvars
│   │   └── prod/
│   │       └── terraform.tfvars
│   └── customer-b/
│       └── ...
│
├── modules/                     # Shared modules
│   ├── platform/                # Platform-level modules
│   │   ├── external-ca/         # External CA abstraction
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── versions.tf
│   │   │   ├── azure/           # Azure implementation
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── outputs.tf
│   │   │   ├── aws/             # AWS implementation
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── outputs.tf
│   │   │   └── alibaba/         # Alibaba implementation
│   │   │       ├── main.tf
│   │   │       ├── variables.tf
│   │   │       └── outputs.tf
│   │   ├── network/             # Network abstraction
│   │   ├── compute/             # Compute abstraction
│   │   └── storage/             # Storage abstraction
│   │
│   ├── shared/                  # Shared utilities (current)
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── tags.tf
│   │   ├── naming.tf            # NEW: Deterministic naming
│   │   ├── tiers.tf             # NEW: Tier maps
│   │   └── validation.tf        # NEW: Input validation
│   │
│   ├── azure/                   # Azure-specific modules
│   │   ├── network/             # Real network module
│   │   ├── compute/             # VM module
│   │   └── aks/                 # AKS module (future)
│   │
│   ├── aws/                     # AWS-specific modules
│   │   ├── network/             # Real network module
│   │   ├── compute/             # EC2 module
│   │   └── eks/                 # EKS module (future)
│   │
│   └── alibaba/                 # Alibaba-specific modules
│       ├── network/
│       ├── compute/
│       └── ack/                 # ACK module (future)
│
└── live/                        # Live state references (optional)
    ├── lab/
    │   ├── aws -> ../../environments/lab/aws
    │   ├── azure -> ../../environments/lab/azure
    │   └── alibaba -> ../../environments/lab/alibaba
    └── prod/
        └── ...
```

#### State Key Naming Convention

```
# AWS S3 State Keys
s3://pki-terraform-state-{account-id}/
├── environments/
│   ├── lab/
│   │   ├── aws/
│   │   │   └── terraform.tfstate
│   │   ├── azure/
│   │   │   └── terraform.tfstate
│   │   └── alibaba/
│   │       └── terraform.tfstate
│   ├── dev/
│   │   └── ...
│   ├── staging/
│   │   └── ...
│   └── prod/
│       └── ...
└── customers/
    ├── customer-a/
    │   ├── lab/
    │   │   └── terraform.tfstate
    │   └── prod/
    │       └── terraform.tfstate
    └── customer-b/
        └── ...

# Azure Blob State Paths
https://{storage}.blob.core.windows.net/tfstate/
├── environments/
│   └── ...
└── customers/
    └── ...

# Alibaba OSS State Paths
oss://pki-terraform-state-{uid}/
├── environments/
│   └── ...
└── customers/
    └── ...
```

---

### 3. Backend Configuration

#### AWS Backend (S3 + DynamoDB)

```hcl
# backends/aws/backend.hcl
bucket         = "pki-terraform-state-123456789012"
key            = "environments/lab/aws/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "alias/terraform-state-key"

dynamodb_table = "terraform-state-locks"

# Optional: assume role for cross-account access
# role_arn       = "arn:aws:iam::123456789012:role/terraform-state-access"
```

```hcl
# environments/lab/aws/backend.tf
terraform {
  backend "s3" {
    # Configuration loaded from backends/aws/backend.hcl
    # via: terraform init -backend-config=../../../backends/aws/backend.hcl
  }
}
```

#### Azure Backend (Blob Storage)

```hcl
# backends/azure/backend.hcl
resource_group_name  = "pki-terraform-state-rg"
storage_account_name = "pkterraformstate"
container_name       = "tfstate"
key                  = "environments/lab/azure/terraform.tfstate"

# Optional: use Azure AD auth
use_azuread_auth     = true
```

```hcl
# environments/lab/azure/backend.tf
terraform {
  backend "azurerm" {
    # Configuration loaded from backends/azure/backend.hcl
    # via: terraform init -backend-config=../../../backends/azure/backend.hcl
  }
}
```

#### Alibaba Backend (OSS + TableStore)

```hcl
# backends/alibaba/backend.hcl
bucket   = "pki-terraform-state-1234567890"
prefix   = "environments/lab/alibaba"
key      = "terraform.tfstate"
region   = "cn-hangzhou"
encrypt  = true

tablestore_table = "terraform-state-locks"
```

```hcl
# environments/lab/alibaba/backend.tf
terraform {
  backend "oss" {
    # Configuration loaded from backends/alibaba/backend.hcl
    # via: terraform init -backend-config=../../../backends/alibaba/backend.hcl
  }
}
```

---

### 4. State Locking

| Cloud | Lock Mechanism | Table/Resource | Notes |
|-------|---------------|----------------|-------|
| AWS | DynamoDB | `terraform-state-locks` | Partition key: `LockID` |
| Azure | Blob Lease | `tfstate` container | Automatic with azurerm backend |
| Alibaba | TableStore | `terraform-state-locks` | Primary key: `LockID` |

**Lock Timeout:** 5 minutes (default)
**Lock Retry:** 3 attempts with exponential backoff

---

### 5. State Encryption

| Layer | Mechanism | Key Management |
|-------|-----------|----------------|
| At Rest | S3 SSE-KMS / Azure Storage Encryption / OSS SSE | Cloud KMS |
| In Transit | TLS 1.2+ | Cloud provider managed |
| Client-Side | Terraform state encryption (1.10+) | Passphrase or KMS |

**Terraform 1.10+ State Encryption:**

```hcl
# In each root module
terraform {
  encryption {
    key_provider "aws_kms" "main" {
      kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/..."
      region     = "us-east-1"
    }
    
    method "aes_gcm" "main" {
      keys = key_provider.aws_kms.main
    }
    
    state {
      method = method.aes_gcm.main
      enforced = true
    }
    
    plan {
      method = method.aes_gcm.main
      enforced = true
    }
  }
}
```

---

### 6. Cross-Environment State Sharing

#### Pattern: Remote State Data Sources

```hcl
# In environments/prod/aws/main.tf
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "pki-terraform-state-123456789012"
    key    = "environments/lab/aws/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use shared outputs
locals {
  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.subnet_ids
}
```

#### Pattern: Shared Configuration Store

For truly global configuration (tier maps, naming rules), use an external store:

```hcl
# Option A: Terraform Cloud Variable Sets
data "tfe_variable_set" "global" {
  name         = "global-configuration"
  organization = "pki-platform"
}

# Option B: Consul KV
data "consul_keys" "global" {
  key {
    name = "tier_map"
    path = "pki-platform/global/tier_map"
  }
}

# Option C: AWS SSM Parameter Store / Azure App Configuration
data "aws_ssm_parameter" "tier_map" {
  name = "/pki-platform/global/tier-map"
}
```

---

### 7. Customer/Environment Separation

#### Isolation Levels

| Level | Mechanism | Use Case |
|-------|-----------|----------|
| **Cloud Account** | Separate AWS accounts / Azure subscriptions / Alibaba accounts | Strongest isolation, billing separation |
| **State Backend** | Separate buckets/containers | Medium isolation, shared account |
| **State Key** | Separate paths in same bucket | Light isolation, shared backend |
| **Directory** | Separate directories, same state | Minimal isolation, same state file |

#### Recommended: Account-Level Isolation for Production

```
Production:
├── AWS Account: pki-prod (123456789012)
│   └── S3: pki-terraform-state-prod
├── Azure Subscription: pki-prod (sub-1234)
│   └── Blob: pkterraformstateprod
└── Alibaba Account: pki-prod (uid-1234)
    └── OSS: pki-terraform-state-prod

Non-Production:
├── AWS Account: pki-nonprod (123456789013)
│   └── S3: pki-terraform-state-nonprod
├── Azure Subscription: pki-nonprod (sub-1235)
│   └── Blob: pkterraformstatenonprod
└── Alibaba Account: pki-nonprod (uid-1235)
    └── OSS: pki-terraform-state-nonprod
```

#### Customer Separation Within Environment

For managed service provider scenarios:

```hcl
# customers/customer-a/prod/aws/terraform.tfvars
customer_id   = "customer-a"
environment   = "prod"
project_name  = "pki-customer-a"
name_prefix   = "pkia"  # Short prefix for customer-a

# Network isolation
network_cidr  = "10.1.0.0/16"  # Unique per customer
subnet_cidr   = "10.1.1.0/24"

# State isolation (if not using separate backends)
# state_key = "customers/customer-a/prod/aws/terraform.tfstate"
```

---

### 8. Import and Migration Patterns

#### Import Existing Infrastructure

```bash
# Step 1: Identify resources to import
terraform plan -generate-config-out=generated.tf

# Step 2: Review generated configuration
cat generated.tf

# Step 3: Import resources
terraform import azurerm_resource_group.main /subscriptions/{sub-id}/resourceGroups/{rg-name}
terraform import azurerm_virtual_network.main /subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.Network/virtualNetworks/{vnet-name}

# Step 4: Verify state matches reality
terraform plan -detailed-exitcode
# Should return 0 (no changes) or 2 (changes to apply)
```

#### Migration Between Backends

```bash
# Step 1: Initialize new backend
terraform init -backend-config=backends/aws/backend.hcl

# Step 2: Migrate state
terraform state pull > terraform.tfstate.backup
terraform init -migrate-state -backend-config=backends/azure/backend.hcl

# Step 3: Verify
terraform plan
```

#### Migration Between Directories

```bash
# Move from infra/terraform/azure/ to environments/lab/azure/
cd environments/lab/azure
terraform init -backend-config=../../../backends/azure/backend.hcl

# Import existing state
terraform import azurerm_resource_group.main /subscriptions/{sub-id}/resourceGroups/pki-rg-abc123
# ... repeat for all resources

# Or use terraform state mv for bulk moves
terraform state mv -state=old/terraform.tfstate -state-out=new/terraform.tfstate azurerm_resource_group.main azurerm_resource_group.main
```

---

### 9. Idempotency Patterns

#### Deterministic Naming

```hcl
# modules/shared/naming.tf
locals {
  # Deterministic suffix from content hash (not random)
  name_suffix = substr(sha256("${var.project_name}${var.environment}${var.cloud_provider}"), 0, 6)
  
  # Resource naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Full resource names
  resource_group_name = "${local.name_prefix}-rg-${local.name_suffix}"
  vnet_name           = "${local.name_prefix}-vnet-${local.name_suffix}"
  vm_name             = "${local.name_prefix}-vm-${local.name_suffix}"
}
```

#### Data Source Over Resource

```hcl
# BAD: Creates new resource each time
resource "aws_ami" "ubuntu" {
  # ... creates new AMI
}

# GOOD: References existing AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

#### Lifecycle Rules for Stability

```hcl
resource "aws_instance" "main" {
  # ...
  
  lifecycle {
    ignore_changes = [
      user_data,           # Ignore cloud-init changes after boot
      ami,                 # Ignore AMI updates (prevent replacement)
      tags["CreatedAt"],   # Ignore timestamp changes
    ]
    
    create_before_destroy = true  # Zero-downtime replacement
  }
}
```

#### Idempotent Bootstrap

```hcl
# Cloud-init should be idempotent
runcmd:
  # Check if already installed before installing
  - |
    if ! command -v k3s &> /dev/null; then
      curl -sfL https://get.k3s.io | sh -
    fi
  
  # Use --skip-if-exists or similar flags
  - kubectl apply -f manifest.yaml  # apply is idempotent
```

---

### 10. State Backup and Recovery

#### Automated Backups

```hcl
# AWS: S3 Versioning + Lifecycle
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  
  rule {
    id     = "state-backup"
    status = "Enabled"
    
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
  }
}
```

#### Manual Backup

```bash
# Backup current state
terraform state pull > backups/terraform.tfstate.$(date +%Y%m%d-%H%M%S)

# Restore from backup
terraform state push backups/terraform.tfstate.20260912-120000
```

#### Disaster Recovery

```bash
# If state is lost but infrastructure exists:
# 1. Re-import all resources
terraform import aws_vpc.main vpc-12345678
terraform import aws_subnet.main subnet-12345678
# ... repeat for all resources

# 2. Verify with plan
terraform plan

# 3. If plan shows changes, reconcile carefully
# - Review each change
# - Use terraform state rm for resources that should be recreated
# - Use terraform import for resources that exist but aren't in state
```

---

### 11. State Security

#### Access Control

| Cloud | Mechanism | Policy |
|-------|-----------|--------|
| AWS | IAM Policy | `s3:GetObject`, `s3:PutObject` on state bucket only |
| Azure | RBAC | `Storage Blob Data Contributor` on state container only |
| Alibaba | RAM Policy | `oss:GetObject`, `oss:PutObject` on state bucket only |

#### State File Hygiene

```bash
# NEVER commit state files
echo "*.tfstate*" >> .gitignore
echo ".terraform/" >> .gitignore

# NEVER store secrets in state (use data sources or external secrets)
# BAD:
variable "db_password" {
  default = "supersecret"  # Ends up in state!
}

# GOOD:
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "pki-platform/db-password"
}
locals {
  db_password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

---

## Summary

| Aspect | Current | Target |
|--------|---------|--------|
| **Backend** | Local | Per-cloud remote (S3/Blob/OSS) |
| **Locking** | None | DynamoDB / Blob Lease / TableStore |
| **Encryption** | None | KMS + TLS |
| **Separation** | Directory | Directory + Account + State Key |
| **Naming** | Random suffix | Deterministic hash |
| **Sharing** | None | Remote state data sources |
| **Backup** | Manual | Versioning + Lifecycle |
| **Import** | Ad-hoc | Documented patterns |
| **Idempotency** | Partial | Comprehensive |

---

## Next Steps

1. Create backend infrastructure (S3 buckets, DynamoDB tables, etc.)
2. Migrate existing local state to remote backends
3. Implement deterministic naming in shared module
4. Create tier maps for provider-neutral sizing
5. Design external-ca module interface
6. Document import patterns for existing infrastructure
