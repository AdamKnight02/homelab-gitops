# PKI Customer Environment Factory — Platform Overview

## Vision

A cloud-agnostic platform that transforms customer intent into fully operational PKI environments through automated pipelines.

## Architecture Principles

### 1. Customer Intent Drives Everything

```yaml
# Customer defines WHAT, not HOW
customer: contoso
environment: production
pki:
  count: 2
  size_class: large  # Not "Standard_D4s_v5"
```

### 2. Cloud-Agnostic Core

The platform model remains provider-neutral. Azure, AWS, and Alibaba are implementation details behind provider adapters.

```
CUSTOMER INTENT
      |
      v
PLATFORM MODEL (cloud-agnostic)
      |
      v
PROVIDER IMPLEMENTATION
      +---- Azure (now)
      +---- AWS (future)
      +---- Alibaba (future)
```

### 3. GitHub as Canonical Source

All code, configuration, and pipeline definitions live in GitHub. Azure DevOps (or GitHub Actions) consumes from GitHub — never the reverse.

### 4. Layered Ownership

| Layer | Owner | Technology |
|-------|-------|------------|
| Customer Intent | Customer Config | YAML schema |
| Infrastructure | Terraform | Provider modules |
| VM Configuration | Configuration Layer | PowerShell/Bash scripts |
| Kubernetes Apps | GitOps | Argo CD |
| Monitoring | Observability | Prometheus/Grafana |

## Component Model

### Compute Abstractions

| Size | vCPU | Memory | Use Case |
|------|------|--------|----------|
| small | 2 | 8 GB | Dev, light workloads |
| medium | 4 | 16 GB | Production standard |
| large | 8 | 32 GB | High-throughput PKI |

### Database Abstractions

| Size | vCPU | Memory | Storage | Use Case |
|------|------|--------|---------|----------|
| small | 2 | 8 GB | 100 GB | Dev |
| medium | 4 | 16 GB | 500 GB | Production |
| large | 8 | 32 GB | 2 TB | High-volume |

### Storage Classes

| Class | Durability | Use Case |
|-------|------------|----------|
| standard | 99.9% | General purpose |
| high_durability | 99.999999999% | CRLs, backups, compliance |

## Deployment Flow

```
Customer Config (YAML)
       |
       v
GitHub Repository
       |
       v
GitHub Actions Pipeline
       |
       +-- Validate Schema
       +-- Terraform Plan
       +-- Security Scan
       +-- Cost Review
       +-- Approval Gate
       +-- Terraform Apply
       +-- VM Configuration
       +-- Argo CD Sync
       +-- Smoke Tests
       |
       v
Operational PKI Environment
```

## Security Boundaries

1. **Pipeline Identity**: GitHub Actions OIDC → Azure/AWS/Alibaba
2. **Terraform Identity**: Service Principal / IAM Role per customer
3. **VM Identity**: Managed Identity / Instance Profile
4. **Workload Identity**: SPIFFE/SPIRE for Kubernetes workloads
5. **PKI Signing Identity**: HSM-backed CA keys, never exported

## Portability Guarantee

Every Azure-specific assumption is isolated behind provider adapters. The same customer configuration can deploy to AWS or Alibaba by changing only:

```yaml
cloud:
  provider: aws  # or alibaba
  region: us-east-1
```

## Next Steps

- [Azure Implementation Guide](../azure/architecture.md)
- [Customer Configuration Schema](../customers/schema/customer-v1.yaml)
- [Terraform Module Architecture](../infra/terraform/README.md)
- [GitOps Architecture](../gitops/README.md)
