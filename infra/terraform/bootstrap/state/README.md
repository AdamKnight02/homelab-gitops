# Azure Remote State Backend — Bootstrap Layer

## Purpose

This bootstrap layer creates the Azure Storage Account and Blob Containers used for Terraform remote state. It is designed to be applied **once per environment** before any other Terraform modules are initialized with remote state.

## Architecture

```
┌─────────────────────────────────────────┐
│  Bootstrap Layer (this directory)       │
│  - Local state (initially)              │
│  - Creates:                             │
│    * Resource Group                     │
│    * Storage Account (Standard LRS)     │
│    * Blob Containers (tfstate, backups) │
│    * RBAC assignments                   │
│    * Management locks                   │
└─────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────┐
│  Remote State Backend                   │
│  - Azure Blob Storage                   │
│  - TLS 1.2+ encryption                  │
│  - Versioning + soft delete             │
│  - Blob lease locking                   │
│  - Network access rules                 │
└─────────────────────────────────────────┘
```

## Usage

### 1. Initialize Bootstrap Layer

```bash
cd infra/terraform/bootstrap/state
terraform init
```

### 2. Plan and Apply

```bash
# Review the plan
terraform plan -var="environment=lab" -var="azure_region=eastus"

# Apply (creates state infrastructure)
terraform apply -var="environment=lab" -var="azure_region=eastus"
```

### 3. Capture Backend Configuration

```bash
# Get the backend configuration for other modules
terraform output backend_config_hcl

# Save to a file for use in other modules
terraform output -raw backend_config_hcl > ../azure/backend.hcl
```

### 4. Migrate Bootstrap to Remote State (Optional)

After the state infrastructure exists, you can migrate the bootstrap layer itself to use remote state:

```bash
# Create backend configuration for bootstrap
cat > backend.hcl << EOF
resource_group_name  = "$(terraform output -raw resource_group_name)"
storage_account_name = "$(terraform output -raw storage_account_name)"
container_name       = "$(terraform output -raw tfstate_container_name)"
key                  = "bootstrap/state/terraform.tfstate"
use_azuread_auth     = true
EOF

# Migrate to remote state
terraform init -migrate-state -backend-config=backend.hcl
```

## Security Features

| Feature | Implementation |
|---------|---------------|
| **Encryption at Rest** | Microsoft-managed keys (default) |
| **Encryption in Transit** | TLS 1.2+ enforced |
| **Authentication** | Azure AD / RBAC (shared key disabled) |
| **Authorization** | Storage Blob Data Contributor role |
| **Network Security** | Default deny, explicit IP/subnet allow |
| **Data Protection** | Versioning + soft delete (30 days) |
| **Audit Logging** | Change feed enabled |
| **Deletion Protection** | Management lock (CanNotDelete) |

## Cost Optimization

| Setting | Lab/Dev | Staging | Production |
|---------|---------|---------|------------|
| **Replication** | LRS | ZRS | GRS |
| **Soft Delete** | 7 days | 30 days | 90 days |
| **Estimated Cost** | ~$1-2/month | ~$2-3/month | ~$3-5/month |

## State Key Naming Convention

```
tfstate/
├── bootstrap/
│   └── state/
│       └── terraform.tfstate          # This bootstrap layer
├── environments/
│   ├── lab/
│   │   ├── azure/
│   │   │   ├── core/
│   │   │   │   └── terraform.tfstate  # Core infrastructure
│   │   │   ├── addons/
│   │   │   │   └── terraform.tfstate  # Add-ons
│   │   │   └── monitoring/
│   │   │       └── terraform.tfstate  # Monitoring
│   │   ├── aws/
│   │   └── alibaba/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── customers/
    ├── customer-a/
    └── customer-b/
```

## Migration from Local State

Use the provided migration script:

```bash
# From the workspace root
./scripts/state-migrate.sh \
  --provider azure \
  --environment lab \
  --component core \
  --source-dir infra/terraform/azure \
  --target-backend bootstrap/state
```

## Safety Rules

1. **Never delete state files** — use `terraform state rm` for resource removal
2. **Never commit state to Git** — `.gitignore` includes `*.tfstate*`
3. **Never print state secrets** — use `sensitive = true` on outputs
4. **Always validate before operations** — use `state-validate.sh`
5. **Always backup before migration** — use `state-backup.sh`

## Troubleshooting

### Storage Account Name Conflicts

Storage account names must be globally unique. If you get a name conflict:

```bash
# The random suffix will change on each apply
terraform apply -var="environment=lab"
```

### Permission Denied

Ensure your Azure credentials have:
- `Contributor` on the subscription or resource group
- `Storage Blob Data Contributor` on the storage account (after creation)

### Network Access Denied

Add your IP to the allowed list:

```bash
terraform apply -var="allowed_ip_ranges=[\"$(curl -s ifconfig.me)/32\"]"
```

## Related Documentation

- [State Architecture](../../../docs/architecture/state-architecture.md)
- [State Migration Guide](../../../docs/migration/state-migration.md)
- [Security Best Practices](../../../docs/security/state-security.md)
