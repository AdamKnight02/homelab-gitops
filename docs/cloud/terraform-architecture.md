# Terraform Architecture

> **Version**: Terraform >= 1.5.0  
> **Status**: Validated for Azure and AWS

## Directory Structure

```
infra/terraform/
├── azure/
│   ├── versions.tf          # Provider version constraints
│   ├── providers.tf         # Provider configuration
│   ├── main.tf              # Core resources (resource group)
│   ├── network.tf           # VNet, subnet, NSG, public IP
│   ├── compute.tf           # VM, disk, NIC
│   ├── variables.tf         # Input variables
│   ├── locals.tf            # Local values
│   ├── outputs.tf           # Output values
│   ├── terraform.tfvars.example  # Example variables
│   ├── cloud-init.yaml      # VM bootstrap script
│   └── README.md            # Documentation
│
└── aws/
    ├── versions.tf          # Provider version constraints
    ├── providers.tf         # Provider configuration
    ├── main.tf              # Core resources (minimal)
    ├── network.tf           # VPC, subnet, IGW, route table, SG
    ├── compute.tf           # EC2, EBS, key pair
    ├── iam.tf               # IAM roles, policies, instance profiles
    ├── data.tf              # Data sources (AMI, AZs)
    ├── variables.tf         # Input variables
    ├── locals.tf            # Local values
    ├── outputs.tf           # Output values
    ├── terraform.tfvars.example  # Example variables
    ├── cloud-init.yaml      # EC2 bootstrap script
    └── README.md            # Documentation
```

## Terraform Concepts Used

### Providers

```hcl
# Azure
provider "azurerm" {
  features {}
}

# AWS
provider "aws" {
  region = var.aws_region
  default_tags { ... }
}
```

### Resources

Infrastructure components created by Terraform:
- `azurerm_resource_group` / `aws_vpc`
- `azurerm_virtual_network` / `aws_subnet`
- `azurerm_linux_virtual_machine` / `aws_instance`
- `azurerm_network_security_group` / `aws_security_group`

### Data Sources

Dynamic lookups:
- `data.aws_ami.ubuntu` — Latest Ubuntu AMI
- `data.aws_availability_zones.available` — Available AZs
- `data.cloudinit_config.bootstrap` — Rendered cloud-init

### Variables

Input parameters for customization:
```hcl
variable "vm_size" {
  description = "Azure VM SKU"
  type        = string
  default     = "Standard_B1s"
}
```

### Locals

Reusable local values:
```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = { ... }
}
```

### Outputs

Exposed values after apply:
```hcl
output "vm_public_ip" {
  value = azurerm_public_ip.main.ip_address
}
```

### Modules

Future expansion: Shared modules for reusable components.

## State Management

### Current: Local State

```bash
# State files are stored locally
terraform.tfstate
terraform.tfstate.backup
```

### Production: Remote State

**Azure**:
```hcl
backend "azurerm" {
  resource_group_name  = "tfstate-rg"
  storage_account_name = "tfstatepki"
  container_name       = "tfstate"
  key                  = "azure.terraform.tfstate"
}
```

**AWS**:
```hcl
backend "s3" {
  bucket         = "tfstate-pki-lab"
  key            = "aws/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-locks"
  encrypt        = true
}
```

## Tagging Strategy

All resources are tagged consistently:

```hcl
tags = {
  project     = "pki-cloudlab"
  environment = "lab"
  managed_by  = "terraform"
  ephemeral   = "true"
  owner       = "terraform-{cloud}-agent"
}
```

## Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| Resource Group | `{project}-{env}-rg` | `pki-cloudlab-lab-rg` |
| VNet/VPC | `{project}-{env}-vnet/vpc` | `pki-cloudlab-lab-vpc` |
| Subnet | `{project}-{env}-subnet` | `pki-cloudlab-lab-subnet` |
| VM/EC2 | `{project}-{env}-vm/ec2` | `pki-cloudlab-lab-ec2` |
| NSG/SG | `{project}-{env}-nsg/sg` | `pki-cloudlab-lab-sg` |

## Validation

```bash
# Format check
terraform fmt -recursive

# Syntax validation
terraform validate

# Plan review
terraform plan -out=plan.tfplan
```

## Security

- Terraform state contains sensitive data — do not commit to Git
- Use `.gitignore` to exclude state files
- Use remote state with encryption for production
- Mark sensitive outputs:
  ```hcl
  output "ssh_private_key" {
    value     = tls_private_key.ssh.private_key_pem
    sensitive = true
  }
  ```
