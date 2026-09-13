# Migration Architecture

## Overview

This document defines the migration architecture for the Machine Identity Platform. It covers local-to-remote state migration, backend migration, and cross-cloud customer migration.

---

## Local-to-Remote State Migration

### Current State

- Terraform state is currently **local** (no state files exist, never applied)
- No backend configs in any .tf files
- Azure and AWS are authenticated; Alibaba CLI is NOT installed

### Target State

- Provider-neutral remote state architecture
- Namespace: `provider/customer/environment/component`
- Backend adapters: Azure Storage, AWS S3+DynamoDB, Alibaba OSS

### Migration Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 1: BACKUP                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Backup      │  │ Checksum    │  │ Verify      │                         │
│  │ Local State │  │ State       │  │ Backup      │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 2: VALIDATE BACKEND                                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Validate    │  │ Validate    │  │ Validate    │                         │
│  │ Backend     │  │ Credentials │  │ Permissions │                         │
│  │ Config      │  │             │  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 3: MIGRATE STATE                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ terraform   │  │ Verify      │  │ Verify      │                         │
│  │ init        │  │ Migration   │  │ Lock        │                         │
│  │ -migrate-   │  │             │  │             │                         │
│  │ state       │  │             │  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 4: VERIFY                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ terraform   │  │ Compare     │  │ Verify      │                         │
│  │ plan        │  │ State       │  │ No Changes  │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Backend Configuration

#### Azure Storage Backend

```hcl
# infra/terraform/azure/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "terraformstate"
    container_name       = "tfstate"
    key                  = "azure/contoso/prod/core/terraform.tfstate"
  }
}
```

#### AWS S3 Backend

```hcl
# infra/terraform/aws/backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "aws/contoso/prod/core/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

#### Alibaba OSS Backend

```hcl
# infra/terraform/alibaba/backend.tf
terraform {
  backend "oss" {
    bucket = "terraform-state-bucket"
    key    = "alibaba/contoso/prod/core/terraform.tfstate"
    region = "cn-hangzhou"
  }
}
```

---

## Cross-Cloud Customer Migration

### Important: Do NOT Use terraform state mv

Do NOT try to directly transform `azurerm_linux_virtual_machine` into `aws_instance` through `terraform state mv`. Those represent different provider resources.

### Migration Orchestrator

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: INVENTORY                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Inventory   │  │ Export      │  │ Classify    │                         │
│  │ Current     │  │ Customer    │  │ PKI         │                         │
│  │ Environment │  │ Intent      │  │ Material    │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: PROVISION TARGET                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Generate    │  │ Terraform   │  │ Deploy      │                         │
│  │ Target Plan │  │ Apply       │  │ PKI         │                         │
│  │             │  │             │  │ Platform    │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: MIGRATE DATA                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Migrate     │  │ Migrate     │  │ Migrate     │                         │
│  │ Config      │  │ Database    │  │ Monitoring  │                         │
│  │             │  │             │  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 4: PKI MIGRATION                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Establish   │  │ Migrate     │  │ Verify      │                         │
│  │ Trust       │  │ CA          │  │ Chain       │                         │
│  │             │  │ Certificates│  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 5: VALIDATE                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Run Smoke   │  │ Compare     │  │ Approval    │                         │
│  │ Tests       │  │ Source/     │  │ Gate        │                         │
│  │             │  │ Target      │  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 6: CUTOVER                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Update DNS  │  │ Update      │  │ Monitor     │                         │
│  │             │  │ Traffic     │  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 7: DECOMMISSION                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Verify      │  │ Destroy     │  │ Verify      │                         │
│  │ Target      │  │ Source      │  │ Cleanup     │                         │
│  │ Stable      │  │             │  │             │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Migration Manifest

```yaml
# migration/contoso-azure-to-aws.yaml
migration:
  customer: contoso

  source:
    provider: azure
    environment: prod
    region: eastus

  target:
    provider: aws
    environment: prod
    region: us-east-1

  strategy:
    type: parallel_cutover
    # parallel_cutover = run both in parallel, cutover when ready
    # blue_green = deploy new, switch traffic, destroy old
    # rolling = migrate components one at a time

  migrate:
    customer_config: true
    application_config: true
    database: true
    monitoring: true
    secrets: true

  preserve:
    trust_chain: true
    certificate_inventory: true
    audit_log: true

  require_manual_approval:
    - ca_keys
    - trust_changes
    - dns_cutover
    - source_destroy

  pki_material:
    root_ca_private_key: NON_EXPORTABLE_KEY_MATERIAL
    issuing_ca_private_key: REQUIRES_SECURE_MIGRATION
    ca_certificates: REQUIRES_SECURE_MIGRATION
    crls: PORTABLE_DATA
    certificate_inventory: PORTABLE_DATA
    audit_logs: PORTABLE_DATA
    configuration: PORTABLE_CONFIG

  validation:
    smoke_tests: true
    compare_source_target: true
    require_approval: true

  cutover:
    dns_update: true
    traffic_switch: true
    observe_period_hours: 24

  decommission:
    destroy_source: true
    verify_cleanup: true
    require_approval: true
```

---

## PKI Material Classification

| Classification | Description | Migration Method | Approval Required |
|---------------|-------------|------------------|-------------------|
| **PORTABLE_CONFIG** | Configuration files, policies | GitOps sync | No |
| **PORTABLE_DATA** | Certificate inventory, audit logs | Database export/import | No |
| **REQUIRES_SECURE_MIGRATION** | CA certificates, CRLs | Secure transfer | Yes |
| **NON_EXPORTABLE_KEY_MATERIAL** | Root CA private keys, HSM keys | Manual ceremony | Yes (explicit) |
| **REQUIRES_MANUAL_APPROVAL** | Issuing CA private keys | Approval gate + secure transfer | Yes (explicit) |

---

## State Safety Rules

### Never Do

- ❌ Manually edit state blindly
- ❌ Commit state to Git
- ❌ Print secrets from state
- ❌ Delete state because Terraform is confused
- ❌ Use the wrong customer's backend
- ❌ Share one state across unrelated customers

### Always Do

- ✅ Backup state before migration
- ✅ Validate backend before migration
- ✅ Verify state after migration
- ✅ Use state locking
- ✅ Encrypt state at rest
- ✅ Validate state identity before operations

---

## State Validation Script

```bash
#!/bin/bash
# scripts/validate-state-identity.sh
# Validates that the current Terraform state matches the expected identity

EXPECTED_PROVIDER="$1"
EXPECTED_CUSTOMER="$2"
EXPECTED_ENVIRONMENT="$3"
EXPECTED_COMPONENT="$4"

EXPECTED_STATE="${EXPECTED_PROVIDER}/${EXPECTED_CUSTOMER}/${EXPECTED_ENVIRONMENT}/${EXPECTED_COMPONENT}"

# Get current state identity
CURRENT_STATE=$(terraform state list | head -1 | cut -d'.' -f1-4 2>/dev/null || echo "unknown")

if [ "$CURRENT_STATE" != "$EXPECTED_STATE" ]; then
  echo "ERROR: State identity mismatch!"
  echo "Expected: $EXPECTED_STATE"
  echo "Current: $CURRENT_STATE"
  echo ""
  echo "This could mean:"
  echo "  - Wrong backend configuration"
  echo "  - Wrong working directory"
  echo "  - Wrong customer/environment"
  echo ""
  echo "DO NOT proceed with plan/apply/destroy."
  exit 1
fi

echo "State identity validated: $CURRENT_STATE"
exit 0
```

---

## State Backup Script

```bash
#!/bin/bash
# scripts/state-backup.sh
# Backs up Terraform state before migration

BACKUP_DIR="${1:-./state-backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

mkdir -p "$BACKUP_PATH"

echo "=== Terraform State Backup ==="
echo "Backup directory: $BACKUP_PATH"
echo ""

# Backup local state
if [ -f "terraform.tfstate" ]; then
  cp terraform.tfstate "${BACKUP_PATH}/terraform.tfstate"
  echo "Backed up: terraform.tfstate"
fi

# Backup state from backend (if configured)
if [ -f "backend.tf" ]; then
  echo "Backend configured — pulling state..."
  terraform state pull > "${BACKUP_PATH}/terraform.tfstate.remote"
  echo "Backed up: terraform.tfstate.remote"
fi

# Calculate checksum
if [ -f "${BACKUP_PATH}/terraform.tfstate" ]; then
  CHECKSUM=$(sha256sum "${BACKUP_PATH}/terraform.tfstate" | cut -d' ' -f1)
  echo "Checksum: $CHECKSUM"
  echo "$CHECKSUM" > "${BACKUP_PATH}/checksum.txt"
fi

echo ""
echo "Backup complete: $BACKUP_PATH"
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial migration architecture |
