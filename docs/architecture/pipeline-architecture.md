# Pipeline Architecture

## Overview

This document defines the pipeline architecture for the Machine Identity Platform. Pipelines are defined in YAML and consumed directly from GitHub by Azure DevOps. The same pipeline definitions can be adapted for GitHub Actions or other CI/CD systems.

---

## Pipeline Types

### 1. Deploy Environment Pipeline

**Purpose:** Deploy a complete customer environment from scratch.

**Trigger:** Manual (with parameters)

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `customer_id` | string | — | Customer identifier (e.g., contoso) |
| `environment` | string | — | Environment (lab, dev, staging, production) |
| `cloud_provider` | string | — | Cloud provider (azure, aws, alibaba) |
| `service_tier` | string | — | Service tier (economy, standard, enterprise) |
| `region_class` | string | primary | Region class (primary, secondary, dr) |
| `scep_enabled` | boolean | false | Enable SCEP protocol |
| `acme_enabled` | boolean | false | Enable ACME protocol |
| `external_ca` | string | none | External CA provider (none, letsencrypt, digicert, sectigo, globalsign, entrust, godaddy, custom) |
| `monitoring_enabled` | boolean | true | Enable monitoring stack |
| `operation` | string | deploy | Operation (deploy, plan, destroy) |

**Stages:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 1: VALIDATE                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Validate    │  │ Validate    │  │ Validate    │  │ Validate    │        │
│  │ Customer    │  │ Schema      │  │ Credentials │  │ Cost        │        │
│  │ Config      │  │ v2          │  │ (if ext CA) │  │ Guardrails  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 2: PLAN                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Terraform   │  │ Resource    │  │ Cost        │  │ Security    │        │
│  │ Plan        │  │ Count Check │  │ Estimate    │  │ Review      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: APPROVAL                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Manual      │  │ Cost        │  │ Security    │                         │
│  │ Approval    │  │ Approval    │  │ Approval    │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: DEPLOY INFRASTRUCTURE                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Terraform   │  │ Wait for    │  │ Verify      │  │ Output      │        │
│  │ Apply       │  │ K3s Ready   │  │ Resources   │  │ State       │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 5: DEPLOY PLATFORM                                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Argo CD     │  │ Wait for    │  │ Verify      │  │ Configure   │        │
│  │ Sync        │  │ Apps Synced │  │ Pods        │  │ External CA │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 6: SMOKE TESTS                                                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Static      │  │ Infra       │  │ K8s         │  │ Platform    │        │
│  │ Validation  │  │ Tests       │  │ Tests       │  │ Tests       │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ PKI         │  │ Monitoring  │  │ External CA │                         │
│  │ Tests       │  │ Tests       │  │ Tests       │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 7: REPORT                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Generate    │  │ Publish     │  │ Notify      │                         │
│  │ Report      │  │ Results     │  │ Stakeholders│                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 2. Deploy Add-On Infrastructure Pipeline

**Purpose:** Add modular capabilities to an existing customer environment.

**Trigger:** Manual (with parameters)

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `customer_id` | string | — | Customer identifier |
| `environment` | string | — | Environment |
| `cloud_provider` | string | — | Cloud provider |
| `addon_type` | string | — | Add-on type (external_ca, scep, acme, monitoring, additional_gateway, additional_worker) |
| `external_ca_provider` | string | none | External CA provider (if addon_type=external_ca) |
| `deployment_profile` | string | standard | Deployment profile (economy, standard, enterprise) |
| `operation` | string | deploy | Operation (deploy, plan, remove) |

**Stages:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 1: VALIDATE                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Load        │  │ Validate    │  │ Check if    │  │ Validate    │        │
│  │ Current     │  │ Add-On      │  │ Already     │  │ Credentials │        │
│  │ State       │  │ Request     │  │ Exists      │  │ (if ext CA) │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 2: PLAN                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Terraform   │  │ Resource    │  │ Cost        │  │ Security    │        │
│  │ Plan        │  │ Count Check │  │ Estimate    │  │ Review      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: APPROVAL                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Manual      │  │ Cost        │  │ Security    │                         │
│  │ Approval    │  │ Approval    │  │ Approval    │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: DEPLOY ADD-ON                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Terraform   │  │ Argo CD     │  │ Configure   │  │ Verify      │        │
│  │ Apply       │  │ Sync        │  │ Add-On      │  │ Deployment  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 5: SMOKE TESTS                                                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Connectivity│  │ Auth        │  │ PKI         │  │ Idempotency │        │
│  │ Tests       │  │ Tests       │  │ Tests       │  │ Tests       │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 6: REPORT                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │ Generate    │  │ Publish     │  │ Notify      │                         │
│  │ Report      │  │ Results     │  │ Stakeholders│                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## External CA Integration Flow

### Deploy Environment with External CA

```
User selects:
  Customer: contoso
  Environment: prod
  Cloud: azure
  Tier: standard
  External CA: DigiCert
  Operation: deploy

Pipeline executes:
  1. Validate customer config
  2. Validate DigiCert credentials exist
  3. Terraform plan (includes external CA infrastructure)
  4. Cost estimate
  5. Security review
  6. Approval
  7. Terraform apply
  8. Argo CD sync (includes external CA gateway)
  9. Smoke tests (including external CA connectivity)
  10. Report
```

### Deploy Add-On: External CA

```
User selects:
  Customer: contoso
  Environment: prod
  Cloud: azure
  Add-On: External CA Integration
  Provider: DigiCert
  Operation: deploy

Pipeline executes:
  1. Load current customer state
  2. Validate add-on request
  3. Check if DigiCert integration already exists
  4. Validate DigiCert credentials exist
  5. Terraform plan (external CA only)
  6. Cost estimate
  7. Security review
  8. Approval
  9. Terraform apply
  10. Argo CD sync (external CA gateway)
  11. Smoke tests (external CA connectivity)
  12. Report
```

### Remove Add-On: External CA

```
User selects:
  Customer: contoso
  Environment: prod
  Cloud: azure
  Add-On: External CA Integration
  Provider: DigiCert
  Operation: remove

Pipeline executes:
  1. Load current customer state
  2. Validate removal request
  3. Show dependencies
  4. Approval
  5. Terraform plan -destroy (external CA only)
  6. Terraform apply (destroy)
  7. Verify internal PKI unaffected
  8. Report
```

---

## Idempotency

### Duplicate Detection

Before deploying an external CA integration, the pipeline checks:

```yaml
checks:
  - name: "Duplicate VM"
    query: "terraform state list | grep external_ca"
    expected: "empty"

  - name: "Duplicate Container"
    query: "kubectl get pods -n pki -l app=external-ca-gateway"
    expected: "empty"

  - name: "Duplicate DNS"
    query: "terraform state list | grep dns"
    expected: "empty"

  - name: "Duplicate Secret"
    query: "kubectl get secrets -n pki | grep external-ca"
    expected: "empty"

  - name: "Duplicate Gateway Registration"
    query: "terraform state list | grep external_ca_gateway"
    expected: "empty"

  - name: "Duplicate Service"
    query: "kubectl get svc -n pki | grep external-ca"
    expected: "empty"

  - name: "Duplicate Argo Application"
    query: "kubectl get applications -n argocd | grep external-ca"
    expected: "empty"

  - name: "Duplicate Namespace"
    query: "kubectl get ns | grep external-ca"
    expected: "empty"

  - name: "Duplicate Role Assignment"
    query: "terraform state list | grep role_assignment"
    expected: "empty"
```

### Expected Behavior

| Scenario | Expected Result |
|----------|-----------------|
| Deploy DigiCert, then deploy DigiCert again | No changes (idempotent) |
| Deploy DigiCert, then deploy Sectigo | New Sectigo integration added |
| Deploy DigiCert, then remove DigiCert | DigiCert removed, others unaffected |
| Deploy DigiCert, then deploy DigiCert with different config | Configuration update only |

---

## Pipeline YAML Structure

### Azure DevOps Pipeline

```yaml
# azure-pipelines/deploy-environment.yml
trigger: none

parameters:
  - name: customer_id
    type: string
  - name: environment
    type: string
    values: [lab, dev, staging, production]
  - name: cloud_provider
    type: string
    values: [azure, aws, alibaba]
  - name: service_tier
    type: string
    values: [economy, standard, enterprise]
  - name: external_ca
    type: string
    default: none
    values: [none, letsencrypt, digicert, sectigo, globalsign, entrust, godaddy, custom]
  - name: operation
    type: string
    default: deploy
    values: [deploy, plan, destroy]

stages:
  - stage: Validate
    jobs:
      - job: ValidateConfig
        steps:
          - task: Bash@3
            inputs:
              targetType: 'inline'
              script: |
                python3 scripts/validate-customer-config.py \
                  --customer ${{ parameters.customer_id }} \
                  --environment ${{ parameters.environment }} \
                  --provider ${{ parameters.cloud_provider }} \
                  --tier ${{ parameters.service_tier }}

  - stage: Plan
    dependsOn: Validate
    jobs:
      - job: TerraformPlan
        steps:
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'plan'
              workingDirectory: 'infra/terraform/${{ parameters.cloud_provider }}'
              environmentServiceNameAzureRM: 'azure-service-connection'

  - stage: Approval
    dependsOn: Plan
    jobs:
      - job: ManualApproval
        pool: server
        steps:
          - task: ManualValidation@0
            inputs:
              notifyUsers: 'security-team@contoso.com'
              instructions: 'Review the Terraform plan and approve deployment.'

  - stage: Deploy
    dependsOn: Approval
    jobs:
      - job: TerraformApply
        steps:
          - task: TerraformTaskV4@4
            inputs:
              provider: 'azurerm'
              command: 'apply'
              workingDirectory: 'infra/terraform/${{ parameters.cloud_provider }}'
              environmentServiceNameAzureRM: 'azure-service-connection'
```

---

## Cost Guardrails

### Pre-Apply Validation

```yaml
# scripts/check-cost-guardrails.py
expected_resources:
  economy:
    vms: 1
    cluster_nodes: 1
    database_instances: 0
    load_balancers: 0
    public_ips: 0
    nat_gateways: 0
    managed_kubernetes: 0

  standard:
    vms: 3
    cluster_nodes: 3
    database_instances: 1
    load_balancers: 1
    public_ips: 1
    nat_gateways: 0
    managed_kubernetes: 0

  enterprise:
    vms: 5
    cluster_nodes: 5
    database_instances: 1
    load_balancers: 2
    public_ips: 2
    nat_gateways: 1
    managed_kubernetes: 0
```

### Hard Stops

| Tier | Resource | Max | Action if Exceeded |
|------|----------|-----|-------------------|
| Economy | VMs | 2 | STOP |
| Economy | Public IPs | 1 | STOP |
| Economy | NAT Gateways | 0 | STOP |
| Economy | Managed K8s | 0 | STOP |
| Standard | VMs | 5 | STOP |
| Standard | Load Balancers | 2 | STOP |
| Enterprise | VMs | 10 | REVIEW |

---

## State Selection Verification

Before every Terraform operation, the pipeline validates:

```bash
# scripts/validate-state-identity.sh
EXPECTED_STATE="azure/contoso/prod/core"
ACTUAL_STATE=$(terraform state list | head -1 | cut -d'.' -f1-4)

if [ "$EXPECTED_STATE" != "$ACTUAL_STATE" ]; then
  echo "ERROR: State identity mismatch!"
  echo "Expected: $EXPECTED_STATE"
  echo "Actual: $ACTUAL_STATE"
  exit 1
fi
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial pipeline architecture |
