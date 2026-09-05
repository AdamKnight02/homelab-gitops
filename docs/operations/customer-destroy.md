# Customer Environment Destroy Runbook

## ⚠️ WARNING

Destroying a customer environment is **IRREVERSIBLE** for PKI data. CA private keys, issued certificates, and audit logs will be permanently deleted unless explicitly backed up.

## Prerequisites

- [ ] Customer approval (written)
- [ ] Security team approval (for production)
- [ ] Backup of CA certificates and keys (if needed)
- [ ] Backup of audit logs (if required for compliance)
- [ ] Verification that no active certificates depend on this PKI

## Destroy Procedure

### 1. Pre-Destroy Verification

```bash
# List all resources that will be destroyed
terraform plan -destroy -target=module.customer_<customer-id>

# Check for active certificates
kubectl exec -n pki-system deployment/ejbca -- ejbca.sh ra listcerts --status active

# Verify no external dependencies
./scripts/check-dependencies.sh <customer-id>
```

### 2. Backup Critical Data (Optional)

```bash
# Backup CA certificates
kubectl exec -n pki-system deployment/ejbca -- ejbca.sh ca exportcacert --caname <ca-name> > backup/<customer>-ca.pem

# Backup database (if needed)
pg_dump -h <postgres-host> -U ejbca ejbca > backup/<customer>-db.sql

# Backup Terraform state
cp terraform.tfstate backup/<customer>-terraform.tfstate
```

### 3. Run Destroy Pipeline

```bash
gh workflow run destroy.yml \
  -f customer_id=<customer-id> \
  -f environment=<env> \
  -f confirm_destroy=true \
  -f backup_completed=true
```

### 4. Manual Approval

The destroy pipeline requires **two manual approvals**:
1. Platform team approval
2. Security team approval (for production)

### 5. Monitor Destroy

Watch for:
- Resources deleted in correct order (dependencies first)
- No orphaned resources
- State file cleaned up

### 6. Post-Destroy Verification

```bash
# Verify no resources remain
az resource list --tag customer=<customer-id>

# Verify Kubernetes namespaces deleted
kubectl get ns | grep <customer-id>

# Verify Argo CD apps removed
argocd app list | grep <customer-id>

# Verify DNS records removed
az network dns zone list --query "[?contains(name, '<customer-id>')]"
```

### 7. Cleanup

```bash
# Remove customer branch
git push origin --delete customer/<customer-id>

# Archive customer config
mv customers/definitions/<customer>-<env>.yaml customers/archive/

# Update inventory
./scripts/update-inventory.sh --remove <customer-id>
```

## What Gets Destroyed

| Resource | Destroyed | Backed Up | Notes |
|----------|-----------|-----------|-------|
| Resource Group | ✅ | ❌ | Contains all Azure resources |
| Virtual Machines | ✅ | ❌ | OS disks deleted |
| Managed Disks | ✅ | ❌ | Data disks deleted |
| PostgreSQL | ✅ | Optional | Point-in-time restore available for 7 days |
| Key Vault | ✅ | ❌ | Soft-delete enabled, purge after 90 days |
| Storage Accounts | ✅ | ❌ | Data permanently deleted |
| Kubernetes Namespaces | ✅ | ❌ | All workloads deleted |
| Argo CD Applications | ✅ | ❌ | Removed from Argo CD |
| DNS Records | ✅ | ❌ | Public DNS records removed |
| CA Private Keys | ✅ | Optional | **IRREVERSIBLE** if not backed up |
| Issued Certificates | ✅ | ❌ | Cannot be recovered |
| Audit Logs | ✅ | Optional | Export before destroy if needed |

## Emergency Destroy

If immediate destroy is required (security incident):

```bash
# Skip approvals (requires platform admin)
gh workflow run destroy.yml \
  -f customer_id=<customer-id> \
  -f environment=<env> \
  -f confirm_destroy=true \
  -f emergency=true
```

**Note**: Emergency destroy bypasses approvals but logs all actions for audit.

## Compliance Considerations

- **SOC 2**: Retain audit logs for 1 year
- **PCI DSS**: Retain CA keys for 3 years after last certificate expires
- **HIPAA**: Retain audit logs for 6 years
- **GDPR**: Right to erasure may require immediate destroy

Consult legal/compliance team before destroying production PKI.

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| Terraform destroy fails | Check for dependencies, use `-target` for specific resources |
| Kubernetes namespace stuck | Force delete with `kubectl delete ns <name> --grace-period=0 --force` |
| Key Vault not deleting | Check soft-delete retention, use `az keyvault purge` if needed |
| PostgreSQL not deleting | Check for active connections, use `az postgres flexible-server delete --yes` |

## Post-Destroy Report

Document:
- Destroy duration
- Resources deleted
- Backups created (if any)
- Issues encountered
- Customer sign-off
