# GitHub Actions Pipeline Architecture

This directory contains the CI/CD workflows for the homelab GitOps infrastructure. All workflows are designed to be **customer-agnostic** — no customer names are hardcoded; they are passed as workflow inputs.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    deploy-customer.yml                          │
│                  (Full Orchestrated Pipeline)                   │
│                                                                 │
│  ① validate ──→ ② plan ──→ ③ approval ──→ ④ apply             │
│                                                  │              │
│                                           ⑤ configure           │
│                                                  │              │
│                                           ⑥ smoke tests         │
│                                                  │              │
│                                          📋 summary             │
└─────────────────────────────────────────────────────────────────┘

Individual workflows (can also be run standalone):
  validate.yml         — Schema, format, lint, security checks
  terraform-plan.yml   — Plan + security scan + cost estimate
  terraform-apply.yml  — Apply with approval gate
  destroy.yml          — Teardown with double approval
```

## Workflows

### 1. `validate.yml` — Validation Pipeline

**Triggers:** `workflow_dispatch`, `push` to main (infra/config paths), `pull_request`

| Job | Description |
|-----|-------------|
| `terraform-fmt` | Checks `terraform fmt` across all modules |
| `terraform-validate` | Runs `terraform validate` for each provider (matrix: azure, aws) |
| `yaml-lint` | Lints all YAML files (manifests, configs, workflows) |
| `k8s-validate` | Validates Kustomize builds and dry-run applies manifests |
| `schema-validate` | Validates YAML parseability, directory structure, required files |
| `secrets-scan` | Scans for hardcoded secrets, API keys, private keys |

**Inputs:**

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `cloud_provider` | choice | Yes | `azure`, `aws`, or `all` |
| `customer_name` | string | No | Customer name for context |

---

### 2. `terraform-plan.yml` — Terraform Plan

**Triggers:** `workflow_dispatch`, `workflow_call` (reusable)

| Job | Description |
|-----|-------------|
| `plan` | Runs `terraform plan` with workspace isolation, uploads plan artifacts |
| `security-scan` | tfsec security scanning with SARIF upload to GitHub Security tab |
| `checkov-scan` | Checkov complementary security scan (soft-fail) |
| `cost-estimate` | Infracost cost estimation (requires `INFRACOST_API_KEY` secret) |
| `plan-summary` | Aggregates all results into a summary |

**Inputs:**

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `cloud_provider` | choice | Yes | — | `azure` or `aws` |
| `customer_name` | string | Yes | — | Customer name (used for workspace) |
| `environment` | choice | Yes | — | `dev`, `staging`, `production` |
| `tfvars_file` | string | No | `terraform.tfvars` | Path to tfvars file |
| `enable_cost_estimate` | boolean | No | `true` | Run Infracost estimation |

**Outputs (workflow_call):**

| Output | Description |
|--------|-------------|
| `plan_exitcode` | Terraform plan exit code (0=no changes, 2=changes) |
| `has_changes` | Whether the plan has changes |

---

### 3. `terraform-apply.yml` — Terraform Apply

**Triggers:** `workflow_dispatch`, `workflow_call` (reusable)

| Job | Description |
|-----|-------------|
| `approval-gate` | Manual approval via GitHub Environments (skipped if `auto_approve=true`) |
| `apply` | Runs `terraform apply`, captures outputs, uploads artifacts |
| `verify` | Post-apply verification and health check placeholders |

**Inputs:**

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `cloud_provider` | choice | Yes | — | `azure` or `aws` |
| `customer_name` | string | Yes | — | Customer name |
| `environment` | choice | Yes | — | `dev`, `staging`, `production` |
| `tfvars_file` | string | No | `terraform.tfvars` | Path to tfvars file |
| `auto_approve` | boolean | No | `false` | Skip approval gate (dev only) |

**Approval Gate:** Uses [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) with required reviewers. The environment name matches the `environment` input (`dev`, `staging`, `production`).

---

### 4. `deploy-customer.yml` — Full Customer Deployment

**Triggers:** `workflow_dispatch`

Orchestrates the complete deployment pipeline by calling reusable workflows:

```
validate → plan → approval → apply → configure → smoke tests → summary
```

**Inputs:**

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `cloud_provider` | choice | Yes | — | `azure` or `aws` |
| `customer_name` | string | Yes | — | Customer name |
| `environment` | choice | Yes | — | `dev`, `staging`, `production` |
| `tfvars_file` | string | No | `terraform.tfvars` | Path to tfvars file |
| `auto_approve` | boolean | No | `false` | Skip approval gates |
| `enable_cost_estimate` | boolean | No | `true` | Include cost estimation |
| `run_smoke_tests` | boolean | No | `true` | Run post-deploy smoke tests |

---

### 5. `destroy.yml` — Environment Teardown

**Triggers:** `workflow_dispatch` only (intentionally no automatic triggers)

**Safety mechanisms:**
1. **Text confirmation** — Must type `DESTROY` to proceed
2. **Production warning** — Extra warnings for production environment
3. **Approval gate** — GitHub Environment approval required (always, even for dev)
4. **State backup** — Terraform state and outputs backed up before destruction (90-day retention)
5. **Workspace cleanup** — Terraform workspace deleted after successful destroy

| Job | Description |
|-----|-------------|
| `confirm` | Validates the `DESTROY` confirmation text |
| `approval` | GitHub Environment approval gate (always required) |
| `backup-state` | Backs up Terraform state, outputs, and resource list |
| `destroy` | Runs `terraform destroy` |
| `cleanup` | Deletes the Terraform workspace |
| `destroy-summary` | Final destruction report |

**Inputs:**

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `cloud_provider` | choice | Yes | — | `azure` or `aws` |
| `customer_name` | string | Yes | — | Customer name (must match workspace) |
| `environment` | choice | Yes | — | `dev`, `staging`, `production` |
| `tfvars_file` | string | No | `terraform.tfvars` | Path to tfvars file |
| `confirm_destroy` | string | Yes | — | Must be exactly `DESTROY` |

---

## Required Secrets

Configure these in **Settings → Secrets and variables → Actions**:

### Azure

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service Principal client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |

### AWS

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `AWS_DEFAULT_REGION` | Default region (optional, defaults to `us-east-1`) |

### Optional

| Secret | Description |
|--------|-------------|
| `INFRACOST_API_KEY` | Infracost API key for cost estimation ([free tier available](https://www.infracost.io/docs/)) |

## GitHub Environments Setup

Create these environments in **Settings → Environments**:

| Environment | Protection Rules |
|-------------|-----------------|
| `dev` | None (or optional reviewers) |
| `staging` | Required reviewers: 1+ |
| `production` | Required reviewers: 2+, wait timer: 5 min, restrict to `main` branch |

## Terraform Workspace Strategy

Each customer/environment combination gets an isolated Terraform workspace:

```
{customer_name}-{environment}
```

Examples:
- `acme-corp-dev`
- `acme-corp-production`
- `contoso-staging`

This ensures state isolation between customers and environments without separate backends.

## Directory Structure

```
.github/workflows/
├── README.md              ← This file
├── validate.yml           ← Validation pipeline
├── terraform-plan.yml     ← Plan + security + cost
├── terraform-apply.yml    ← Apply with approval
├── deploy-customer.yml    ← Full orchestrated deployment
├── destroy.yml            ← Environment teardown
├── argo-sync-check.yaml   ← (Legacy) ArgoCD sync checker
└── pki-validation.yaml    ← (Legacy) PKI manifest validation

infra/terraform/
├── azure/                 ← Azure provider configs
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── terraform.tfvars.example
├── aws/                   ← AWS provider configs
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── terraform.tfvars.example
└── modules/               ← Shared modules
    └── shared/
        ├── naming/
        └── tags/
```

## Security Scanning

Two complementary tools are used:

| Tool | Purpose | Fail on Finding? |
|------|---------|-----------------|
| **tfsec** | Terraform-specific security issues | Yes (blocking) |
| **Checkov** | Broader policy-as-code checks | No (soft-fail, informational) |

tfsec results are uploaded to GitHub's Security tab via SARIF for tracking.

## Cost Estimation

[Infracost](https://www.infracost.io/) integration provides cost estimates during the plan phase. To enable:

1. Sign up at https://www.infracost.io/ (free tier available)
2. Add `INFRACOST_API_KEY` to repository secrets
3. Cost estimates appear in the plan summary and artifacts

If the API key is not configured, cost estimation is gracefully skipped.

## Adding a New Customer

1. Create a tfvars file for the customer (e.g., `infra/terraform/azure/customers/acme.tfvars`)
2. Run the **Deploy Customer Environment** workflow with:
   - `customer_name`: `acme`
   - `environment`: `dev`
   - `tfvars_file`: `customers/acme.tfvars`
3. The pipeline handles workspace creation, planning, approval, and deployment

## Adding a New Cloud Provider

1. Create `infra/terraform/<provider>/` with standard Terraform files
2. Add the provider to the `cloud_provider` choice options in each workflow
3. Add provider-specific authentication step (e.g., `gcloud auth`, `doctl auth`)
4. Add the provider to the `terraform-validate` matrix in `validate.yml`
