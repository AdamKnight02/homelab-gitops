# Customer Upgrade Runbook

## Overview

Upgrading a customer environment involves updating the platform version, configuration changes, or scaling resources.

## Upgrade Types

| Type | Risk Level | Approval Required | Downtime |
|------|-----------|-------------------|----------|
| Platform version update | Medium | Platform team | Possible |
| Configuration change | Low | Customer + Platform | No |
| Scale up/down | Low | Customer | No |
| PKI CA rotation | High | Security team + Customer | Yes |

## Pre-Upgrade Checklist

- [ ] Backup current state (Terraform state, PKI database)
- [ ] Review changelog for breaking changes
- [ ] Test upgrade in dev/staging environment
- [ ] Schedule maintenance window (if downtime required)
- [ ] Notify customer of planned upgrade
- [ ] Verify rollback procedure

## Upgrade Procedure

### 1. Platform Version Upgrade

```bash
# Update platform version in customer config
yq eval '.platform_version = "1.2.3"' -i customers/definitions/<customer>-<env>.yaml

# Commit and push
git checkout customer/<customer-id>
git add customers/definitions/<customer>-<env>.yaml
git commit -m "chore(customer): upgrade platform to v1.2.3"
git push origin customer/<customer-id>
```

### 2. Run Upgrade Pipeline

```bash
gh workflow run deploy-customer.yml \
  -f customer_id=<customer-id> \
  -f environment=<env> \
  -f operation=upgrade
```

### 3. Monitor Upgrade

Watch for:
- Terraform plan shows expected changes only
- No unexpected resource replacements
- Argo CD syncs without errors
- Health checks pass after upgrade

### 4. Post-Upgrade Verification

```bash
# Verify platform version
kubectl get deployment -n pki-system -o jsonpath='{.items[*].spec.template.spec.containers[*].image}'

# Verify certificate issuance still works
./scripts/smoke-test.sh <customer-id> <env>

# Check for any drift
terraform plan -detailed-exitcode
```

## Configuration Changes

For non-platform changes (e.g., scaling, feature toggles):

```bash
# Update customer config
yq eval '.pki.count = 3' -i customers/definitions/<customer>-<env>.yaml

# Commit and deploy
git checkout customer/<customer-id>
git add customers/definitions/<customer>-<env>.yaml
git commit -m "feat(customer): scale PKI to 3 instances"
git push origin customer/<customer-id>

# Pipeline auto-triggers on push to customer branch
```

## Rollback

If upgrade causes issues:

```bash
# Revert to previous commit
git revert HEAD
git push origin customer/<customer-id>

# Or trigger destroy and redeploy from known-good state
gh workflow run destroy.yml -f customer_id=<customer-id> -f environment=<env>
# Then redeploy from previous commit
```

## PKI-Specific Upgrade Considerations

### CA Certificate Renewal

1. Generate new CA certificate (offline ceremony for Root CA)
2. Update EJBCA with new CA certificate
3. Publish new CRL
4. Update OCSP responder
5. Verify certificate chain

### HSM Key Rotation

1. Generate new key in HSM
2. Update EJBCA crypto token
3. Migrate certificates to new key
4. Decommission old key (after verification)

**NEVER** rotate Root CA keys without explicit security team approval and customer notification.

## Monitoring During Upgrade

- Watch Prometheus for error rates
- Monitor Grafana dashboards for latency spikes
- Check Argo CD for sync failures
- Review Azure Monitor for resource health

## Post-Upgrade Report

Document:
- Upgrade duration
- Issues encountered
- Resolution steps
- Customer impact
- Lessons learned
