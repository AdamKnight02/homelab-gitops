# Lifecycle Tests

## Overview

Lifecycle tests validate the complete infrastructure lifecycle: **deploy → test → destroy → verify cleanup → redeploy → test**. These are **destructive tests** that create and destroy real cloud resources.

**⚠️ WARNING:** Lifecycle tests will create and destroy cloud resources. Only run against ephemeral environments with `ephemeral=true`.

---

## Lifecycle Stages

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│  Safety  │──▶│  Deploy  │──▶│ Validate │──▶│ Destroy  │──▶│  Verify  │──▶│ Redeploy │
│  Check   │   │          │   │          │   │          │   │ Cleanup  │   │          │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └────┬─────┘
                                                                                 │
                                                                          ┌──────▼──────┐
                                                                          │  Validate   │
                                                                          │  (Again)    │
                                                                          └─────────────┘
```

### Stage 1: Ephemeral Safety Check

Verifies the target environment is safe for destructive testing:

- Checks `terraform.tfvars` for `ephemeral=true`
- Checks `variables.tf` for ephemeral default
- **BLOCKED** if environment appears to be persistent

### Stage 2: Terraform Deploy

Runs `terraform init` + `terraform plan` + `terraform apply`:

- Initializes Terraform backend
- Creates execution plan
- Applies infrastructure changes
- **SKIP** if state already exists (already deployed)

### Stage 3: Post-Deploy Validation

Validates deployed infrastructure:

- Collects Terraform outputs
- Verifies expected outputs exist
- Checks resource accessibility

### Stage 4: Terraform Destroy

Runs `terraform destroy -auto-approve`:

- Destroys all managed resources
- **FAIL** if destroy encounters errors (manual cleanup may be needed)

### Stage 5: Cleanup Verification

Verifies complete resource cleanup:

- Checks Terraform state is empty
- **Azure:** Verifies no resource groups remain
- **AWS:** Verifies no VPCs remain
- **FAIL** if orphaned resources detected

### Stage 6: Terraform Redeploy

Re-runs `terraform apply` after destroy:

- Validates reproducibility
- Confirms infrastructure can be recreated from scratch
- **SKIP** if state already has resources

### Stage 7: Post-Redeploy Validation

Final validation after redeployment:

- Collects Terraform outputs
- Verifies infrastructure is functional

---

## Running Lifecycle Tests

### Prerequisites

1. **Cloud credentials configured** (Azure CLI or AWS CLI authenticated)
2. **Terraform initialized** in the target provider directory
3. **Ephemeral environment** — `ephemeral=true` in tfvars or variables
4. **No production state** — lifecycle tests are destructive

### Azure Lifecycle

```bash
python3 tests/run_tests.py --level 7 --provider azure
```

### AWS Lifecycle

```bash
python3 tests/run_tests.py --level 7 --provider aws
```

### Full Suite with Lifecycle

```bash
python3 tests/run_tests.py --level all-live --provider azure
```

---

## Safety Mechanisms

| Mechanism | Description |
|-----------|-------------|
| Ephemeral check | Verifies `ephemeral=true` before any destructive action |
| State check | Skips deploy if state already exists |
| Provider check | Verifies cloud CLI is available and authenticated |
| Cleanup verify | Confirms all resources destroyed after test |
| BLOCKED status | Returns BLOCKED (not FAIL) for safety violations |

---

## Idempotency Testing (Level 6)

Related to lifecycle tests, idempotency tests validate that repeated operations produce the same result:

### Terraform Idempotency

- Runs `terraform plan` after apply
- **PASS** if no changes detected (exit code 0)
- **FAIL** if pending changes (exit code 2)
- **SKIP** if no state file (PLAN-ONLY mode)

### Kubernetes Manifest Idempotency

- Captures current resource state hash
- Compares after re-apply
- Ignores volatile fields (resourceVersion, uid, timestamps)

### ArgoCD Sync Drift

- Checks all ArgoCD applications for `OutOfSync` status
- **FAIL** if any app shows drift after sync

### Kustomize Build Determinism

- Runs `kubectl kustomize` twice on each overlay
- **PASS** if output is identical
- **FAIL** if non-deterministic output detected

---

## Provider-Specific Notes

### Azure

- Uses `az group list` to verify cleanup
- Resource groups named with `pki` prefix
- NSG rules validated for restrictiveness
- Public IPs audited

### AWS

- Uses `aws ec2 describe-vpcs` with Project tag filter
- EBS encryption validated
- Security group rules audited
- Elastic IPs tracked

### Alibaba Cloud

- **BLOCKED** — `aliyun` CLI not installed
- Terraform configuration exists but cannot be planned/applied
- All Alibaba lifecycle tests return BLOCKED

---

## Cost Considerations

Lifecycle tests create real cloud resources with real costs:

| Provider | Tier | Estimated Cost per Test Cycle |
|----------|------|-------------------------------|
| Azure | Economy | ~$0.25 (B1s, ~1 hour) |
| Azure | Standard | ~$1.00 (B2s, ~1 hour) |
| AWS | Economy | ~$0.01 (t3.micro, free-tier) |
| AWS | Standard | ~$0.05 (t3.small, ~1 hour) |

**Recommendations:**
- Run lifecycle tests during off-peak hours
- Use economy tier for testing
- Set up billing alerts
- Always verify cleanup after tests

---

## Troubleshooting

### "terraform destroy failed"

Manual cleanup may be required:
```bash
# Azure
az group delete --name <resource-group> --yes --no-wait

# AWS
aws ec2 delete-vpc --vpc-id <vpc-id>
# (may need to delete dependencies first)
```

### "State still contains resources"

```bash
# Force refresh state
terraform refresh

# Check for resources
terraform state list

# Remove specific resource from state (does NOT destroy)
terraform state rm <resource-address>
```

### "Orphaned resources detected"

Some resources may not be managed by Terraform (e.g., manually created). Check cloud console and delete manually.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | QA Agent | Initial lifecycle test documentation |
