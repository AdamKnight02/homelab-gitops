# Customer Deployment Runbook

## Prerequisites

- [ ] Customer configuration file created in `customers/definitions/`
- [ ] GitHub repository access confirmed
- [ ] Azure subscription access confirmed
- [ ] Terraform state backend accessible
- [ ] Argo CD admin access (for manual syncs)

## Deployment Steps

### 1. Validate Customer Configuration

```bash
# Validate YAML schema
yq eval '.schema_version' customers/definitions/<customer>-<env>.yaml

# Validate against JSON schema (if available)
python -c "import yaml, jsonschema; yaml.safe_load(open('customers/definitions/<customer>-<env>.yaml'))"
```

### 2. Create Customer Branch

```bash
git checkout -b customer/<customer-id>
git add customers/definitions/<customer>-<env>.yaml
git commit -m "feat(customer): add <customer> <env> configuration"
git push origin customer/<customer-id>
```

### 3. Run Deployment Pipeline

Trigger the GitHub Actions workflow:

```bash
gh workflow run deploy-customer.yml \
  -f customer_id=<customer-id> \
  -f environment=<env> \
  -f operation=deploy
```

Or via GitHub UI: Actions → Deploy Customer Environment → Run workflow

### 4. Monitor Pipeline Stages

| Stage | Expected Duration | Success Criteria |
|-------|-------------------|------------------|
| Validate | 1-2 min | Schema valid, no Terraform errors |
| Plan | 2-5 min | Plan generated, cost estimated |
| Security Scan | 1-3 min | No critical findings |
| Approval | Manual | Approved by platform team |
| Apply | 10-30 min | Resources created successfully |
| Configure | 5-15 min | VMs configured, baseline applied |
| GitOps Sync | 5-10 min | Argo CD apps synced |
| Smoke Tests | 2-5 min | All health checks pass |

### 5. Post-Deployment Verification

```bash
# Verify Azure resources
az resource list --tag customer=<customer-id> --output table

# Verify Kubernetes
kubectl get pods -n customer-<customer-id>

# Verify Argo CD
argocd app list | grep <customer-id>

# Verify PKI
curl -k https://<gateway-url>/ejbca/adminweb/
```

### 6. Handover to Customer

Provide:
- [ ] Gateway URL
- [ ] Admin credentials (via secure channel)
- [ ] Argo CD read-only access
- [ ] Grafana dashboard URL
- [ ] Runbook for common operations

## Rollback Procedure

If deployment fails after Apply stage:

```bash
# Trigger destroy workflow
gh workflow run destroy.yml \
  -f customer_id=<customer-id> \
  -f environment=<env> \
  -f confirm_destroy=true
```

## Troubleshooting

### Common Issues

| Issue | Symptom | Resolution |
|-------|---------|------------|
| Schema validation fails | Pipeline exits at Validate stage | Check YAML syntax, verify required fields |
| Terraform plan fails | Plan stage error | Check Azure quotas, verify provider version |
| Cost estimate too high | Approval rejected | Review size_class selections, consider smaller sizes |
| VM configuration fails | Configure stage error | Check VM extension logs, verify script syntax |
| Argo CD sync fails | Apps not syncing | Check network policies, verify RBAC |
| PKI not accessible | Smoke test fails | Check gateway configuration, verify DNS |

### Escalation

1. Check pipeline logs in GitHub Actions
2. Review Terraform state for resource status
3. Check Azure Activity Log for deployment errors
4. Review Argo CD application events
5. Contact platform team with correlation ID

## Security Notes

- Never commit secrets to Git
- Use Azure Key Vault for all credentials
- Rotate service principal secrets after each deployment
- Review NSG rules before enabling public access
- Enable Azure Defender for all subscriptions
