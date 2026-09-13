# Local to Remote State Migration Guide

## Overview

This document provides a comprehensive runbook for migrating Terraform state from local files to remote backends. The migration process ensures zero data loss, maintains state integrity, and establishes proper locking and encryption.

**Scope:** Azure, AWS, and Alibaba Cloud backends  
**Prerequisites:** Terraform >= 1.10.0, appropriate cloud CLI authentication  
**Estimated Time:** 30-60 minutes per environment

---

## Pre-Migration Checklist

### 1. Environment Verification

```bash
# Verify Terraform version
terraform version
# Required: >= 1.10.0

# Verify cloud authentication
az account show                    # Azure
aws sts get-caller-identity        # AWS
# aliyun sts GetCallerIdentity     # Alibaba (when CLI available)

# Verify current state location
ls -la infra/terraform/*/terraform.tfstate 2>/dev/null || echo "No local state files found"
```

### 2. Backup Current State

**CRITICAL:** Always backup before migration.

```bash
# Run the backup script
./scripts/state-backup.sh --all

# Or manually for a specific environment
cd infra/terraform/azure
terraform state pull > ../../../backups/azure/terraform.tfstate.$(date +%Y%m%d-%H%M%S)
```

### 3. Validate State Integrity

```bash
# Run state validation
./scripts/state-validate.sh --provider azure --environment lab

# Verify no pending changes
cd infra/terraform/azure
terraform plan -detailed-exitcode
# Expected: 0 (no changes) or 2 (changes present)
# If 1 (error), resolve before proceeding
```

---

## Backend Architecture

### State Namespace Convention

```
{provider}/{customer}/{environment}/{component}

Examples:
- azure/default/lab/compute
- aws/customer-a/prod/network
- alibaba/default/staging/pki
```

### Backend Configuration Files

Create backend configuration files for each provider:

#### Azure Backend

```hcl
# backends/azure/backend.hcl
resource_group_name  = "pki-terraform-state-rg"
storage_account_name = "pkterraformstate"
container_name       = "tfstate"
key                  = "azure/default/lab/terraform.tfstate"
use_azuread_auth     = true
```

#### AWS Backend

```hcl
# backends/aws/backend.hcl
bucket         = "pki-terraform-state-123456789012"
key            = "aws/default/lab/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "alias/terraform-state-key"
dynamodb_table = "terraform-state-locks"
```

#### Alibaba Backend

```hcl
# backends/alibaba/backend.hcl
bucket   = "pki-terraform-state-1234567890"
prefix   = "alibaba/default/lab"
key      = "terraform.tfstate"
region   = "cn-hangzhou"
encrypt  = true
tablestore_table = "terraform-state-locks"
```

---

## Migration Procedures

### Phase 1: Azure Migration

#### Step 1: Create Backend Infrastructure

```bash
# Create resource group
az group create \
  --name pki-terraform-state-rg \
  --location eastus

# Create storage account
az storage account create \
  --name pkterraformstate \
  --resource-group pki-terraform-state-rg \
  --location eastus \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name tfstate \
  --account-name pkterraformstate \
  --auth-mode login
```

#### Step 2: Configure Backend

```bash
cd infra/terraform/azure

# Create backend.tf
cat > backend.tf << 'EOF'
terraform {
  backend "azurerm" {
    # Configuration from backends/azure/backend.hcl
  }
}
EOF
```

#### Step 3: Migrate State

```bash
# Initialize with migration
terraform init -migrate-state \
  -backend-config=../../../backends/azure/backend.hcl

# Verify migration
terraform plan
# Expected: No changes. Plan: 0 to add, 0 to change, 0 to destroy.
```

#### Step 4: Post-Migration Validation

```bash
# Verify state is in Azure
az storage blob list \
  --container-name tfstate \
  --account-name pkterraformstate \
  --auth-mode login \
  --output table

# Verify lock mechanism
terraform plan -lock=true
# Should complete without errors

# Compare state checksums
terraform state pull | sha256sum
# Compare with backup checksum
```

---

### Phase 2: AWS Migration

#### Step 1: Create Backend Infrastructure

```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket pki-terraform-state-123456789012 \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket pki-terraform-state-123456789012 \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket pki-terraform-state-123456789012 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "alias/terraform-state-key"
      }
    }]
  }'

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

#### Step 2: Configure Backend

```bash
cd infra/terraform/aws

# Create backend.tf
cat > backend.tf << 'EOF'
terraform {
  backend "s3" {
    # Configuration from backends/aws/backend.hcl
  }
}
EOF
```

#### Step 3: Migrate State

```bash
# Initialize with migration
terraform init -migrate-state \
  -backend-config=../../../backends/aws/backend.hcl

# Verify migration
terraform plan
# Expected: No changes
```

#### Step 4: Post-Migration Validation

```bash
# Verify state is in S3
aws s3 ls s3://pki-terraform-state-123456789012/aws/default/lab/

# Verify lock table
aws dynamodb scan --table-name terraform-state-locks

# Test lock acquisition
terraform plan -lock=true
```

---

### Phase 3: Alibaba Migration (Future)

#### Step 1: Create Backend Infrastructure

```bash
# Create OSS bucket
aliyun oss mb oss://pki-terraform-state-1234567890 \
  --region cn-hangzhou

# Enable versioning
aliyun oss versioning put oss://pki-terraform-state-1234567890 enabled

# Create TableStore table for locking
aliyun tablestore CreateTable \
  --table_name terraform-state-locks \
  --primary_key LockID:String
```

#### Step 2: Configure Backend

```bash
cd infra/terraform/alibaba

# Create backend.tf
cat > backend.tf << 'EOF'
terraform {
  backend "oss" {
    # Configuration from backends/alibaba/backend.hcl
  }
}
EOF
```

#### Step 3: Migrate State

```bash
terraform init -migrate-state \
  -backend-config=../../../backends/alibaba/backend.hcl

terraform plan
```

---

## Rollback Procedures

### If Migration Fails

```bash
# Step 1: Restore from backup
cd infra/terraform/azure
terraform state push ../../../backups/azure/terraform.tfstate.20260912-120000

# Step 2: Remove backend configuration
rm backend.tf

# Step 3: Re-initialize with local backend
terraform init -reconfigure

# Step 4: Verify
terraform plan
```

### If State is Corrupted

```bash
# Step 1: Pull current remote state (if accessible)
terraform state pull > corrupted.tfstate

# Step 2: Restore from backup
terraform state push ../../../backups/azure/terraform.tfstate.20260912-120000

# Step 3: Verify
terraform plan
```

---

## Post-Migration Tasks

### 1. Update .gitignore

```bash
# Ensure state files are never committed
cat >> .gitignore << 'EOF'
# Terraform state files
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform/
.terraform.lock.hcl
EOF
```

### 2. Update CI/CD Pipelines

```yaml
# Example GitHub Actions step
- name: Terraform Init
  run: |
    terraform init \
      -backend-config=backends/${{ matrix.provider }}/backend.hcl
```

### 3. Document State Locations

Create a state inventory document:

```markdown
# State Inventory

| Provider | Environment | Backend | State Key | Last Verified |
|----------|-------------|---------|-----------|---------------|
| Azure    | lab         | Blob    | azure/default/lab/terraform.tfstate | 2026-09-12 |
| AWS      | lab         | S3      | aws/default/lab/terraform.tfstate   | 2026-09-12 |
| Alibaba  | lab         | OSS     | alibaba/default/lab/terraform.tfstate | N/A |
```

### 4. Schedule Regular Backups

```bash
# Add to cron or scheduled task
0 2 * * * /path/to/scripts/state-backup.sh --all --remote
```

---

## Troubleshooting

### Common Issues

#### Issue: "Backend configuration changed"

```bash
# Solution: Reconfigure backend
terraform init -reconfigure -backend-config=backends/azure/backend.hcl
```

#### Issue: "State lock timeout"

```bash
# Check for stale locks
az storage blob lease list --container-name tfstate --account-name pkterraformstate

# Break stale lease (if safe)
az storage blob lease break --blob-name terraform.tfstate --container-name tfstate --account-name pkterraformstate
```

#### Issue: "State checksum mismatch"

```bash
# Pull fresh state
terraform state pull > current.tfstate

# Compare with backup
sha256sum current.tfstate backup.tfstate

# If different, investigate before proceeding
terraform plan -refresh-only
```

#### Issue: "Provider authentication failed"

```bash
# Re-authenticate
az login
aws sso login
# or
aws configure
```

---

## Security Considerations

1. **State Encryption**: All backends must have encryption at rest enabled
2. **Access Control**: Use IAM/RBAC with least privilege
3. **Audit Logging**: Enable cloud audit logs for state access
4. **Network Security**: Use private endpoints where available
5. **Key Rotation**: Rotate KMS keys annually

---

## References

- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/backend)
- [Azure Backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [S3 Backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [OSS Backend](https://developer.hashicorp.com/terraform/language/backend/oss)
- [State Migration](https://developer.hashicorp.com/terraform/cli/commands/init#backend-initialization)
