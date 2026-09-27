# Terraform Stage: Per-Root Check Findings

## AWS Root

### Critical Findings

### Warning Findings
- [WARN] homelab-gitops/infra/terraform/aws/providers.tf: backend configured for S3 with key 'aws/terraform.tfstate'

### Info Findings
- [INFO] homelab-gitops/infra/terraform/aws/providers.tf: backend configured for S3 with key 'aws/terraform.tfstate'

## Azure Root

### Critical Findings

### Warning Findings
- [WARN] homelab-gitops/infra/terraform/azure/backend.tf: backend configured for azurerm

### Info Findings
- [INFO] homelab-gitops/infra/terraform/azure/backend.tf: backend configured for azurerm

## Alibaba Root

### Critical Findings

### Warning Findings

### Info Findings
- [INFO] No findings.

## Bootstrap State Root

### Critical Findings

### Warning Findings
- [WARN] backend.tf: Current backend is configured as 'local' with path = 'terraform.tfstate'. This is for initial bootstrap before migrating to remote state.

### Info Findings
- [INFO] backend.tf: Current backend is configured as 'local' with path = 'terraform.tfstate'. This is for initial bootstrap before migrating to remote state.

## Summary

- 14 of 24 checks failing
- Critical findings: 0
- Warning findings: 3
- Info findings: 4
