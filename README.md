# PKI Customer Environment Factory

A cloud-agnostic platform for deploying and managing PKI customer environments at scale.

## Architecture

```
Customer Configuration (YAML)
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

## Repository Structure

```
homelab-gitops/
├── .github/workflows/          # GitHub Actions pipelines
├── customers/                  # Customer configurations
│   ├── schema/                 # Customer config schema
│   ├── examples/               # Example configurations
│   └── definitions/            # Actual customer configs (gitignored)
├── docs/                       # Documentation
│   ├── architecture/           # Platform architecture
│   ├── azure/                  # Azure-specific docs
│   ├── operations/             # Runbooks
│   └── learning/               # Learning resources
├── gitops/                     # GitOps/Argo CD manifests
│   ├── applications/           # Argo CD Applications
│   ├── projects/               # Argo CD AppProjects
│   ├── base/                   # Base Kubernetes manifests
│   ├── overlays/               # Environment overlays
│   └── bootstrap/              # Argo CD bootstrap
├── infra/terraform/            # Terraform infrastructure
│   ├── modules/                # Terraform modules
│   │   ├── shared/             # Cloud-agnostic modules
│   │   ├── azure/              # Azure provider modules
│   │   ├── aws/                # AWS provider modules (future)
│   │   └── alibaba/            # Alibaba provider modules (future)
│   └── environments/           # Root module compositions
├── configuration/              # VM configuration scripts
│   ├── windows/                # Windows PowerShell scripts
│   └── linux/                  # Linux bash scripts
└── apps/                       # Application manifests (existing)
```

## Quick Start

### 1. Create Customer Configuration

```bash
cp customers/examples/contoso-prod.yaml customers/definitions/my-customer-prod.yaml
# Edit with your customer details
```

### 2. Deploy via GitHub Actions

```bash
gh workflow run deploy-customer.yml \
  -f customer_id=my-customer \
  -f environment=prod \
  -f operation=deploy
```

### 3. Monitor Deployment

Watch the pipeline in GitHub Actions. The deployment includes:
- Schema validation
- Terraform plan with cost estimation
- Security scanning
- Manual approval
- Infrastructure deployment
- VM configuration
- Argo CD sync
- Smoke tests

## Key Features

- **Cloud-Agnostic**: Deploy to Azure, AWS, or Alibaba with the same customer config
- **GitOps-Driven**: All state in Git, reconciled by Argo CD
- **Security-First**: HSM-backed CA keys, least-privilege access, network segmentation
- **Cost-Optimized**: Right-sizing, auto-shutdown, reserved instances
- **Compliance-Ready**: SOC 2, PCI DSS, HIPAA controls built-in

## Documentation

- [Platform Overview](docs/architecture/platform-overview.md)
- [Cloud Portability](docs/architecture/cloud-portability.md)
- [Security Architecture](docs/architecture/security.md)
- [Azure Cost Guide](docs/azure/cost.md)
- [Customer Deployment Runbook](docs/operations/customer-deployment.md)
- [Customer Upgrade Runbook](docs/operations/customer-upgrade.md)
- [Customer Destroy Runbook](docs/operations/customer-destroy.md)

## Contributing

1. Create a feature branch from `main`
2. Make changes
3. Run validation: `terraform fmt -recursive && terraform validate`
4. Submit PR with clear description
5. Require approval from platform team

## License

Internal use only. Proprietary.
