# Backend Migration Guide

## Overview

This document describes the process for migrating Terraform state between different backend types (e.g., local to S3, S3 to Azure Blob, etc.). It covers backend validation, state integrity verification, and rollback procedures.

**Scope:** All supported backends (local, S3, Azure Blob, OSS, Consul, Kubernetes)  
**Prerequisites:** Terraform >= 1.10.0, access to both source and target backends  
**Risk Level:** Medium (state corruption possible if procedures not followed)

---

## Backend Types and Compatibility

### Supported Backends

| Backend | Locking | Encryption | Versioning | Multi-Region |
|---------|---------|------------|------------|--------------|
| **local** | No | No | Manual | N/A |
| **s3** | DynamoDB | SSE-KMS | Yes | Yes |
| **azurerm** | Blob Lease | Storage Encryption | Yes | Yes |
| **oss** | TableStore | SSE | Yes | Yes |
| **consul** | Yes | TLS | Yes | Yes |
| **kubernetes** | ConfigMap/Secret | etcd encryption | etcd versioning | Cluster-dependent |

### Migration Compatibility Matrix

| From \ To | local | s3 | azurerm | oss | consul |
|-----------|-------|-----|---------|-----|--------|
| **local** | - | ✅ | ✅ | ✅ | ✅ |
| **s3** | ✅ | - | ✅ | ✅ | ✅ |
| **azurerm** | ✅ | ✅ | - | ✅ | ✅ |
| **oss** | ✅ | ✅ | ✅ | - | ✅ |
| **consul** | ✅ | ✅ | ✅ | ✅ | - |

---

## Pre-Migration Validation

### 1. Source Backend Validation

```bash
# Verify source backend is accessible
terraform state pull > /dev/null && echo "Source backend accessible"

# Check state version
terraform state pull | jq '.version'
# Should be >= 4 (Terraform 0.12+)

# Verify no pending operations
terraform plan -detailed-exitcode
# Must be 0 or 2, not 1
```

### 2. Target Backend Validation

```bash
# For S3
aws s3 ls s3://target-bucket/ --region target-region

# For Azure Blob
az storage blob list --container-name tfstate --account-name targetaccount

# For OSS
aliyun oss ls oss://target-bucket/ --region target-region
```

### 3. State Backup

```bash
# Create timestamped backup
BACKUP_FILE="backups/$(date +%Y%m%d-%H%M%S)-terraform.tfstate"
terraform state pull > "$BACKUP_FILE"

# Verify backup
terraform state pull | sha256sum
sha256sum "$BACKUP_FILE"
# Checksums must match
```

---

## Migration Procedures

### Method 1: terraform init -migrate-state (Recommended)

This is the safest method for migrating between backends.

```bash
# Step 1: Configure new backend
cat > backend.tf << 'EOF'
terraform {
  backend "s3" {
    bucket         = "new-state-bucket"
    key            = "path/to/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}
EOF

# Step 2: Initialize with migration
terraform init -migrate-state

# Step 3: Verify
terraform plan
# Expected: No changes
```

### Method 2: Manual State Push/Pull

Use when `migrate-state` is not available or fails.

```bash
# Step 1: Pull from source
terraform state pull > migration.tfstate

# Step 2: Configure new backend (remove old backend config first)
rm backend.tf
cat > backend.tf << 'EOF'
terraform {
  backend "azurerm" {
    resource_group_name  = "state-rg"
    storage_account_name = "stateaccount"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
EOF

# Step 3: Initialize new backend (without migration)
terraform init -reconfigure

# Step 4: Push state to new backend
terraform state push migration.tfstate

# Step 5: Verify
terraform plan
```

### Method 3: terraform state mv (For Resource Moves)

Use when moving resources between states, not backends.

```bash
# Move resource to different state file
terraform state mv \
  -state=source.tfstate \
  -state-out=target.tfstate \
  aws_instance.example aws_instance.example
```

---

## Backend-Specific Migration Guides

### Local to S3

```bash
# 1. Create S3 backend infrastructure
aws s3api create-bucket --bucket pki-terraform-state --region us-east-1
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# 2. Configure backend
cat > backend.tf << 'EOF'
terraform {
  backend "s3" {
    bucket         = "pki-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
EOF

# 3. Migrate
terraform init -migrate-state

# 4. Verify
terraform plan
aws s3 ls s3://pki-terraform-state/
```

### S3 to Azure Blob

```bash
# 1. Pull state from S3
terraform state pull > s3-backup.tfstate

# 2. Create Azure backend infrastructure
az group create --name pki-terraform-state-rg --location eastus
az storage account create \
  --name pkterraformstate \
  --resource-group pki-terraform-state-rg \
  --sku Standard_LRS
az storage container create \
  --name tfstate \
  --account-name pkterraformstate

# 3. Remove S3 backend, add Azure backend
rm backend.tf
cat > backend.tf << 'EOF'
terraform {
  backend "azurerm" {
    resource_group_name  = "pki-terraform-state-rg"
    storage_account_name = "pkterraformstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
EOF

# 4. Initialize and push
terraform init -reconfigure
terraform state push s3-backup.tfstate

# 5. Verify
terraform plan
az storage blob list --container-name tfstate --account-name pkterraformstate
```

### Azure Blob to OSS

```bash
# 1. Pull state from Azure
terraform state pull > azure-backup.tfstate

# 2. Create OSS backend infrastructure
aliyun oss mb oss://pki-terraform-state --region cn-hangzhou
aliyun tablestore CreateTable \
  --table_name terraform-state-locks \
  --primary_key LockID:String

# 3. Remove Azure backend, add OSS backend
rm backend.tf
cat > backend.tf << 'EOF'
terraform {
  backend "oss" {
    bucket = "pki-terraform-state"
    prefix = "terraform"
    key    = "terraform.tfstate"
    region = "cn-hangzhou"
    tablestore_table = "terraform-state-locks"
  }
}
EOF

# 4. Initialize and push
terraform init -reconfigure
terraform state push azure-backup.tfstate

# 5. Verify
terraform plan
aliyun oss ls oss://pki-terraform-state/terraform/
```

---

## State Locking Verification

### Verify Lock Acquisition

```bash
# Terminal 1: Start a long-running operation
terraform plan -lock=true -lock-timeout=5m

# Terminal 2: Attempt concurrent operation (should fail)
terraform plan -lock=true -lock-timeout=10s
# Expected: Error acquiring state lock
```

### Verify Lock Release

```bash
# After operation completes, verify lock is released
terraform plan -lock=true -lock-timeout=10s
# Should succeed immediately
```

### Force Unlock (Emergency Only)

```bash
# List locks
terraform force-unlock -list

# Force unlock (use with extreme caution)
terraform force-unlock <LOCK_ID>
```

---

## Post-Migration Validation

### 1. State Integrity Check

```bash
# Compare resource counts
terraform state list | wc -l
# Compare with backup count

# Verify specific resources
terraform state show azurerm_resource_group.main
terraform state show aws_vpc.main
```

### 2. Plan Verification

```bash
# Run plan with detailed exit code
terraform plan -detailed-exitcode

# Exit codes:
# 0 = No changes
# 1 = Error
# 2 = Changes present

# If 2, investigate before proceeding
terraform plan -out=plan.out
terraform show plan.out
```

### 3. Apply Verification (Optional)

```bash
# Only if plan shows expected changes
terraform apply plan.out

# Verify no unexpected changes
terraform plan -detailed-exitcode
# Should return 0
```

### 4. State Comparison

```bash
# Pull current state
terraform state pull > current.tfstate

# Compare with backup
terraform show -json current.tfstate | jq '.values.root_module.resources | length'
terraform show -json backup.tfstate | jq '.values.root_module.resources | length'

# Compare specific attributes
terraform show -json current.tfstate | \
  jq '.values.root_module.resources[] | select(.address=="aws_vpc.main") | .values.cidr_block'
```

---

## Rollback Procedures

### Rollback to Previous Backend

```bash
# Step 1: Restore state from backup
terraform state push backups/20260912-120000-terraform.tfstate

# Step 2: Revert backend configuration
git checkout backend.tf  # or restore from backup

# Step 3: Re-initialize
terraform init -reconfigure

# Step 4: Verify
terraform plan
```

### Rollback to Local State

```bash
# Step 1: Pull remote state
terraform state pull > rollback.tfstate

# Step 2: Remove backend configuration
rm backend.tf

# Step 3: Re-initialize with local backend
terraform init -reconfigure

# Step 4: Push state
terraform state push rollback.tfstate

# Step 5: Verify
terraform plan
```

---

## Automation Scripts

### Backend Migration Script

```bash
#!/bin/bash
# scripts/migrate-backend.sh

set -euo pipefail

SOURCE_BACKEND="$1"
TARGET_BACKEND="$2"
BACKUP_DIR="backups/$(date +%Y%m%d-%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup current state
echo "Backing up state..."
terraform state pull > "$BACKUP_DIR/terraform.tfstate"

# Verify backup
if ! terraform state pull | sha256sum | grep -q "$(sha256sum < "$BACKUP_DIR/terraform.tfstate" | cut -d' ' -f1)"; then
  echo "ERROR: Backup verification failed"
  exit 1
fi

# Configure new backend
echo "Configuring $TARGET_BACKEND backend..."
case "$TARGET_BACKEND" in
  s3)
    cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "${S3_BUCKET}"
    key            = "${S3_KEY}"
    region         = "${S3_REGION}"
    dynamodb_table = "${S3_DYNAMODB_TABLE}"
    encrypt        = true
  }
}
EOF
    ;;
  azurerm)
    cat > backend.tf << EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "${AZURE_RG}"
    storage_account_name = "${AZURE_SA}"
    container_name       = "${AZURE_CONTAINER}"
    key                  = "${AZURE_KEY}"
  }
}
EOF
    ;;
  *)
    echo "ERROR: Unsupported backend: $TARGET_BACKEND"
    exit 1
    ;;
esac

# Migrate
echo "Migrating state..."
terraform init -migrate-state

# Verify
echo "Verifying migration..."
if ! terraform plan -detailed-exitcode; then
  echo "ERROR: Migration verification failed"
  echo "Rolling back..."
  terraform state push "$BACKUP_DIR/terraform.tfstate"
  exit 1
fi

echo "Migration successful"
echo "Backup location: $BACKUP_DIR/terraform.tfstate"
```

---

## Best Practices

1. **Always backup before migration** — No exceptions
2. **Verify state integrity** — Compare checksums and resource counts
3. **Test in non-production first** — Migrate dev/staging before prod
4. **Use migrate-state when possible** — It's the safest method
5. **Document state locations** — Maintain an inventory of all state files
6. **Enable versioning** — Protect against accidental deletion
7. **Monitor lock tables** — Clean up stale locks regularly
8. **Restrict access** — Use IAM/RBAC with least privilege

---

## Troubleshooting

### Issue: "Backend initialization failed"

```bash
# Check backend configuration
terraform init -backend-config=backend.hcl -reconfigure

# Verify credentials
aws sts get-caller-identity
az account show
```

### Issue: "State lock timeout"

```bash
# Check for stale locks
aws dynamodb scan --table-name terraform-state-locks

# Force unlock if safe
terraform force-unlock <LOCK_ID>
```

### Issue: "State checksum mismatch after migration"

```bash
# Pull fresh state
terraform state pull > current.tfstate

# Compare with backup
terraform show -json current.tfstate | jq -S '.values' > current.json
terraform show -json backup.tfstate | jq -S '.values' > backup.json
diff current.json backup.json
```

---

## References

- [Terraform Backend Migration](https://developer.hashicorp.com/terraform/cli/commands/init#backend-initialization)
- [State Locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [State Push/Pull](https://developer.hashicorp.com/terraform/cli/commands/state/push)
