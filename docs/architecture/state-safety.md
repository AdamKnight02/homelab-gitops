# =============================================================================
# State Safety and Concurrency Validation
# =============================================================================
# This document defines the safety rules and concurrency protection mechanisms
# for Terraform state operations in the PKI platform.
#
# CRITICAL: These rules must be enforced before ANY state operation.
# =============================================================================

## State Safety Rules

### Rule 1: Never Delete State

**Rationale:** State files are the source of truth for infrastructure. Deleting state orphans resources and makes them unmanageable.

**Enforcement:**
- Management lock (CanNotDelete) on state storage account
- Soft delete enabled with 30-day retention
- `prevent_destroy = true` on all state infrastructure resources
- `terraform state rm` for resource removal, never `rm terraform.tfstate`

### Rule 2: Never Commit State to Git

**Rationale:** State files contain sensitive data (resource IDs, IP addresses, sometimes secrets). Committing them to Git exposes this data and creates merge conflicts.

**Enforcement:**
- `.gitignore` includes `*.tfstate*` and `.terraform/`
- Pre-commit hooks check for state files
- CI/CD pipelines fail if state files are detected
- Regular audits with `git ls-files | grep -E '\.tfstate'`

### Rule 3: Never Print State Secrets

**Rationale:** State files may contain sensitive outputs. Printing them to logs or console exposes secrets.

**Enforcement:**
- All sensitive outputs marked with `sensitive = true`
- `terraform output` without `-json` or `-raw` for sensitive values
- Log scrubbing in CI/CD pipelines
- No `echo` of state file contents

### Rule 4: Never Use Wrong Customer State

**Rationale:** Using the wrong customer state can modify or destroy another customer's infrastructure.

**Enforcement:**
- State key naming: `customers/{customer}/{environment}/{provider}/{component}/terraform.tfstate`
- Backend configuration validation before operations
- Identity checks in `state-guard.sh`
- Customer-specific state storage accounts for production

## Concurrency Protection

### Azure Blob Lease Locking

Azure Blob Storage uses blob leases for state locking. When Terraform acquires a lock:

1. It creates a lease on the state blob
2. The lease has a 60-second duration
3. Terraform renews the lease every 15 seconds during operations
4. If Terraform crashes, the lease expires after 60 seconds

**Lock Timeout:** 5 minutes (default)
**Lock Retry:** 3 attempts with exponential backoff

### Lock Validation

Before any state operation, validate:

```bash
# Check if state is locked
terraform plan -lock=true -lock-timeout=5s -input=false

# Force unlock (ONLY if you're certain no one else is using it)
terraform force-unlock <LOCK_ID>
```

### Concurrent Operation Prevention

| Operation | Lock Type | Duration | Notes |
|-----------|-----------|----------|-------|
| `terraform plan` | Shared | Read-only | Multiple plans can run concurrently |
| `terraform apply` | Exclusive | Write | Blocks all other operations |
| `terraform destroy` | Exclusive | Write | Blocks all other operations |
| `terraform import` | Exclusive | Write | Blocks all other operations |
| `terraform state mv` | Exclusive | Write | Blocks all other operations |

## State Identity Validation

Before any operation, validate:

1. **Provider:** azure, aws, or alibaba
2. **Customer:** default or specific customer ID
3. **Environment:** lab, dev, staging, or prod
4. **Component:** core, addons, or monitoring
5. **Backend:** Matches expected storage account and container
6. **State Key:** Matches expected path

### Validation Script

Use `state-guard.sh` before any operation:

```bash
# Before plan
./scripts/state-guard.sh --provider azure --environment lab --component core --operation plan

# Before apply
./scripts/state-guard.sh --provider azure --environment lab --component core --operation apply --strict

# Before destroy
./scripts/state-guard.sh --provider azure --environment lab --component core --operation destroy --strict
```

## Migration Safety

### Pre-Migration Checklist

- [ ] State backup created and verified
- [ ] Target backend validated (storage account, container, permissions)
- [ ] Source state identity verified (provider, environment, component)
- [ ] No state files in Git
- [ ] No hardcoded secrets in .tf files
- [ ] `.gitignore` includes state patterns
- [ ] Migration script reviewed and tested

### Migration Procedure

```bash
# 1. Backup state
./scripts/state-backup.sh --provider azure --environment lab

# 2. Validate target backend
./scripts/state-validate.sh --provider azure --environment lab

# 3. Migrate state
./scripts/state-migrate.sh --provider azure --environment lab --component core

# 4. Verify migration
cd infra/terraform/azure
terraform plan  # Should show no changes
```

### Post-Migration Checklist

- [ ] `terraform plan` shows no unexplained changes
- [ ] `terraform state list` shows expected resources
- [ ] State file no longer exists locally (or is backed up)
- [ ] CI/CD pipelines updated to use new backend
- [ ] Documentation updated

## Emergency Procedures

### State Corruption

If state becomes corrupted:

1. **DO NOT** run `terraform apply` or `terraform destroy`
2. Restore from backup:
   ```bash
   cp backups/state/azure/lab/terraform.tfstate.YYYYMMDD-HHMMSS infra/terraform/azure/terraform.tfstate
   ```
3. Verify with `terraform plan`
4. If plan shows changes, reconcile carefully

### State Lock Stuck

If state lock is stuck:

1. Identify the lock:
   ```bash
   terraform force-unlock
   ```
2. Verify no one else is running Terraform
3. Force unlock:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

### Wrong Environment Modified

If you accidentally modify the wrong environment:

1. **DO NOT** run `terraform apply` to "fix" it
2. Document what was changed
3. Restore from backup if available
4. Contact the infrastructure team immediately

## Compliance

### Audit Logging

All state operations are logged:
- Azure Storage Account change feed
- Terraform Cloud/Enterprise audit logs (if used)
- Local logs in `.work/agent-state/`

### Retention

| Data | Retention | Location |
|------|-----------|----------|
| State versions | 90 days | Azure Blob versioning |
| Soft-deleted blobs | 30 days | Azure Blob soft delete |
| State backups | 90 days | Azure Blob `state-backups` container |
| Guard reports | 30 days | `.work/agent-state/` |
| Migration reports | 90 days | `.work/agent-state/` |

## Related Documentation

- [State Architecture](../docs/architecture/state-architecture.md)
- [State Migration Guide](../docs/migration/state-migration.md)
- [Security Best Practices](../docs/security/state-security.md)
