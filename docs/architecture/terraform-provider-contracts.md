# Terraform Provider Contracts

## Overview

This document defines the contracts and interfaces that all cloud provider adapters must implement for the PKI Platform. It ensures consistency, portability, and testability across Azure, AWS, and Alibaba Cloud.

**Design Principles:**
- **Provider-neutral interface**: Consumers use abstract types, not provider-specific resources
- **Deterministic behavior**: Same inputs produce same outputs across providers
- **Idempotent operations**: All modules can be applied repeatedly without side effects
- **Composable**: Modules can be combined to build complex infrastructure
- **Testable**: Contracts enable mocking and validation

---

## Contract Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLATFORM CONTRACTS                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  external-  │  │   network   │  │   compute   │              │
│  │     ca      │  │             │  │             │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   storage   │  │   identity  │  │   secrets   │              │
│  │             │  │             │  │             │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  AZURE        │    │     AWS       │    │   ALIBABA     │
│  ADAPTER      │    │   ADAPTER     │    │   ADAPTER     │
│               │    │               │    │               │
│  Implements   │    │  Implements   │    │  Implements   │
│  platform     │    │  platform     │    │  platform     │
│  contracts    │    │  contracts    │    │  contracts    │
│  using Azure  │    │  using AWS    │    │  using Ali    │
│  resources    │    │  resources    │    │  resources    │
└───────────────┘    └───────────────┘    └───────────────┘
```

---

## Core Contracts

### 1. Network Contract

#### Interface Definition

```hcl
# modules/platform/network/variables.tf
variable "name" {
  description = "Name prefix for all network resources"
  type        = string
}

variable "cidr_block" {
  description = "Primary CIDR block for the network"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "CIDR block must be valid"
  }
}

variable "subnets" {
  description = "Map of subnet names to CIDR blocks"
  type        = map(string)
  
  validation {
    condition     = alltrue([for cidr in values(var.subnets) : can(cidrhost(cidr, 0))])
    error_message = "All subnet CIDRs must be valid"
  }
}

variable "enable_internet_gateway" {
  description = "Whether to create an internet gateway"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT gateway (cost warning)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/platform/network/outputs.tf
output "network_id" {
  description = "Provider-specific network identifier"
  value       = ""  # Implemented by each provider
}

output "network_name" {
  description = "Provider-specific network name"
  value       = ""
}

output "subnet_ids" {
  description = "Map of subnet names to provider-specific subnet IDs"
  value       = {}
}

output "subnet_cidrs" {
  description = "Map of subnet names to CIDR blocks"
  value       = {}
}

output "route_table_ids" {
  description = "Map of route table names to IDs"
  value       = {}
}

output "security_group_ids" {
  description = "Map of security group names to IDs"
  value       = {}
}

output "nat_gateway_ips" {
  description = "List of NAT gateway public IPs (if enabled)"
  value       = []
}
```

#### Provider Implementations

**Azure Implementation:**
```hcl
# modules/platform/network/azure/main.tf
resource "azurerm_virtual_network" "main" {
  name                = "${var.name}-vnet"
  address_space       = [var.cidr_block]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "main" {
  for_each = var.subnets
  
  name                 = "${var.name}-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]
}

# ... additional Azure-specific resources
```

**AWS Implementation:**
```hcl
# modules/platform/network/aws/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_subnet" "main" {
  for_each = var.subnets
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

# ... additional AWS-specific resources
```

**Alibaba Implementation:**
```hcl
# modules/platform/network/alibaba/main.tf
resource "alicloud_vpc" "main" {
  vpc_name   = "${var.name}-vpc"
  cidr_block = var.cidr_block
  tags       = var.tags
}

resource "alicloud_vswitch" "main" {
  for_each = var.subnets
  
  vswitch_name = "${var.name}-${each.key}"
  vpc_id       = alicloud_vpc.main.id
  cidr_block   = each.value
  zone_id      = data.alicloud_zones.available.zones[0].id
  tags         = var.tags
}

# ... additional Alibaba-specific resources
```

---

### 2. Compute Contract

#### Interface Definition

```hcl
# modules/platform/compute/variables.tf
variable "name" {
  description = "Name prefix for compute resources"
  type        = string
}

variable "tier" {
  description = "Provider-neutral tier (small, medium, large, xlarge)"
  type        = string
  default     = "small"
  
  validation {
    condition     = contains(["small", "medium", "large", "xlarge"], var.tier)
    error_message = "Tier must be one of: small, medium, large, xlarge"
  }
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10"
  }
}

variable "os_image" {
  description = "Operating system image identifier"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "admin_username" {
  description = "Administrator username"
  type        = string
  default     = "admin"
}

variable "ssh_public_key" {
  description = "SSH public key for access"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID from network module"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "Cloud-init or user data script"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/platform/compute/outputs.tf
output "instance_ids" {
  description = "List of instance IDs"
  value       = []
}

output "instance_private_ips" {
  description = "List of private IP addresses"
  value       = []
}

output "instance_public_ips" {
  description = "List of public IP addresses (if any)"
  value       = []
}

output "ssh_private_key" {
  description = "Generated SSH private key (if not provided)"
  value       = ""
  sensitive   = true
}

output "ssh_public_key" {
  description = "SSH public key used"
  value       = ""
}
```

---

### 3. External CA Contract

#### Interface Definition

```hcl
# modules/platform/external-ca/variables.tf
variable "name" {
  description = "Name prefix for CA resources"
  type        = string
}

variable "ca_type" {
  description = "Type of external CA (ejbca, vault, aws-pca, azure-keyvault, alibaba-kms)"
  type        = string
  
  validation {
    condition     = contains(["ejbca", "vault", "aws-pca", "azure-keyvault", "alibaba-kms"], var.ca_type)
    error_message = "CA type must be one of: ejbca, vault, aws-pca, azure-keyvault, alibaba-kms"
  }
}

variable "tier" {
  description = "Provider-neutral tier for CA infrastructure"
  type        = string
  default     = "small"
}

variable "trust_domain" {
  description = "SPIFFE trust domain"
  type        = string
  default     = "pki.local"
}

variable "root_ca_config" {
  description = "Root CA configuration"
  type = object({
    common_name  = string
    organization = string
    country      = string
    validity_years = number
  })
  default = {
    common_name    = "PKI Platform Root CA"
    organization   = "PKI Platform"
    country        = "US"
    validity_years = 10
  }
}

variable "issuing_ca_config" {
  description = "Issuing CA configuration"
  type = object({
    common_name  = string
    organization = string
    country      = string
    validity_years = number
  })
  default = {
    common_name    = "PKI Platform Issuing CA"
    organization   = "PKI Platform"
    country        = "US"
    validity_years = 5
  }
}

variable "database_config" {
  description = "Database configuration for CA"
  type = object({
    type     = string
    host     = string
    port     = number
    name     = string
    username = string
  })
  default = {
    type     = "postgresql"
    host     = "localhost"
    port     = 5432
    name     = "cadb"
    username = "caadmin"
  }
}

variable "enable_ocsp" {
  description = "Enable OCSP responder"
  type        = bool
  default     = true
}

variable "enable_crl" {
  description = "Enable CRL distribution"
  type        = bool
  default     = true
}

variable "enable_est" {
  description = "Enable EST enrollment"
  type        = bool
  default     = true
}

variable "enable_scep" {
  description = "Enable SCEP enrollment"
  type        = bool
  default     = false
}

variable "enable_acme" {
  description = "Enable ACME enrollment"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/platform/external-ca/outputs.tf
output "ca_id" {
  description = "Provider-specific CA identifier"
  value       = ""
}

output "root_ca_certificate" {
  description = "Root CA certificate (PEM)"
  value       = ""
  sensitive   = true
}

output "issuing_ca_certificate" {
  description = "Issuing CA certificate (PEM)"
  value       = ""
  sensitive   = true
}

output "issuing_ca_private_key" {
  description = "Issuing CA private key (PEM)"
  value       = ""
  sensitive   = true
}

output "ocsp_responder_url" {
  description = "OCSP responder URL"
  value       = ""
}

output "crl_distribution_point" {
  description = "CRL distribution point URL"
  value       = ""
}

output "est_enrollment_url" {
  description = "EST enrollment URL"
  value       = ""
}

output "scep_enrollment_url" {
  description = "SCEP enrollment URL"
  value       = ""
}

output "acme_directory_url" {
  description = "ACME directory URL"
  value       = ""
}

output "database_connection_string" {
  description = "Database connection string"
  value       = ""
  sensitive   = true
}

output "ca_admin_credentials" {
  description = "CA administrator credentials"
  value = {
    username = ""
    password = ""
  }
  sensitive = true
}
```

#### Provider Implementations

**EJBCA Implementation (Provider-Neutral):**
```hcl
# modules/platform/external-ca/ejbca/main.tf
# Deploys EJBCA on Kubernetes (cloud-neutral)

resource "helm_release" "ejbca" {
  name       = "${var.name}-ejbca"
  repository = "oci://repo.keyfactor.com/charts"
  chart      = "ejbca-ce"
  version    = var.ejbca_version
  
  namespace = var.namespace
  
  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      database_host     = var.database_config.host
      database_port     = var.database_config.port
      database_name     = var.database_config.name
      database_username = var.database_config.username
      root_ca_config    = var.root_ca_config
      issuing_ca_config = var.issuing_ca_config
      enable_ocsp       = var.enable_ocsp
      enable_est        = var.enable_est
    })
  ]
}
```

**AWS PCA Implementation:**
```hcl
# modules/platform/external-ca/aws-pca/main.tf
resource "aws_acmpca_certificate_authority" "root" {
  type = "ROOT"
  
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"
    
    subject {
      common_name  = var.root_ca_config.common_name
      organization = var.root_ca_config.organization
      country      = var.root_ca_config.country
    }
  }
  
  permanent_deletion_time_in_days = 7
  
  tags = var.tags
}

resource "aws_acmpca_certificate_authority" "issuing" {
  type = "SUBORDINATE"
  
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"
    
    subject {
      common_name  = var.issuing_ca_config.common_name
      organization = var.issuing_ca_config.organization
      country      = var.issuing_ca_config.country
    }
  }
  
  tags = var.tags
}

# ... additional PCA resources
```

**Azure Key Vault Implementation:**
```hcl
# modules/platform/external-ca/azure-keyvault/main.tf
resource "azurerm_key_vault" "ca" {
  name                = "${var.name}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
  
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  
  purge_protection_enabled = true
  
  tags = var.tags
}

resource "azurerm_key_vault_certificate" "root_ca" {
  name         = "root-ca"
  key_vault_id = azurerm_key_vault.ca.id
  
  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    
    key_properties {
      exportable = true
      key_size   = 4096
      key_type   = "RSA"
      reuse_key  = false
    }
    
    secret_properties {
      content_type = "application/x-pem-file"
    }
    
    x509_certificate_properties {
      subject            = "CN=${var.root_ca_config.common_name}, O=${var.root_ca_config.organization}, C=${var.root_ca_config.country}"
      validity_in_months = var.root_ca_config.validity_years * 12
      
      key_usage = [
        "cRLSign",
        "keyCertSign",
      ]
      
      basic_constraints {
        is_ca_certificate = true
      }
    }
  }
}

# ... additional Key Vault resources
```

**Alibaba KMS Implementation:**
```hcl
# modules/platform/external-ca/alibaba-kms/main.tf
resource "alicloud_kms_key" "ca" {
  description            = "${var.name} CA key"
  key_usage              = "SIGN/VERIFY"
  customer_master_key_spec = "RSA_4096"
  key_state              = "Enabled"
  
  tags = var.tags
}

# Alibaba Cloud doesn't have a native CA service like AWS PCA
# Use KMS for key management + cert-manager for certificate issuance
resource "alicloud_kms_alias" "ca" {
  alias_name = "alias/${var.name}-ca"
  key_id     = alicloud_kms_key.ca.id
}

# ... additional KMS resources
```

---

## Tier Maps

### Provider-Neutral Tier Definitions

```hcl
# modules/shared/tiers.tf
locals {
  # Provider-neutral tier definitions
  tiers = {
    small = {
      description = "Minimal resources for lab/dev"
      cpu_cores   = 2
      memory_gb   = 4
      disk_gb     = 30
      cost_tier   = "burstable"
    }
    medium = {
      description = "Standard resources for staging"
      cpu_cores   = 4
      memory_gb   = 8
      disk_gb     = 50
      cost_tier   = "balanced"
    }
    large = {
      description = "High resources for production"
      cpu_cores   = 8
      memory_gb   = 16
      disk_gb     = 100
      cost_tier   = "performance"
    }
    xlarge = {
      description = "Maximum resources for high-load production"
      cpu_cores   = 16
      memory_gb   = 32
      disk_gb     = 200
      cost_tier   = "performance"
    }
  }
  
  # Provider-specific SKU mappings
  azure_skus = {
    small  = "Standard_B2s"
    medium = "Standard_B2ms"
    large  = "Standard_D4s_v3"
    xlarge = "Standard_D8s_v3"
  }
  
  aws_instance_types = {
    small  = "t3.medium"
    medium = "t3.large"
    large  = "m5.xlarge"
    xlarge = "m5.2xlarge"
  }
  
  alibaba_instance_types = {
    small  = "ecs.t6-c1m2.large"
    medium = "ecs.t6-c1m4.large"
    large  = "ecs.g6.xlarge"
    xlarge = "ecs.g6.2xlarge"
  }
  
  # Storage mappings
  azure_disk_types = {
    small  = "StandardSSD_LRS"
    medium = "PremiumSSD_LRS"
    large  = "PremiumSSD_LRS"
    xlarge = "PremiumSSD_LRS"
  }
  
  aws_volume_types = {
    small  = "gp3"
    medium = "gp3"
    large  = "io2"
    xlarge = "io2"
  }
  
  alibaba_disk_types = {
    small  = "cloud_efficiency"
    medium = "cloud_ssd"
    large  = "cloud_essd"
    xlarge = "cloud_essd"
  }
}
```

### Usage in Modules

```hcl
# In compute module
locals {
  # Resolve tier to provider-specific SKU
  instance_type = var.cloud_provider == "azure" ? local.azure_skus[var.tier] :
                  var.cloud_provider == "aws" ? local.aws_instance_types[var.tier] :
                  var.cloud_provider == "alibaba" ? local.alibaba_instance_types[var.tier] :
                  "unknown"
  
  disk_type = var.cloud_provider == "azure" ? local.azure_disk_types[var.tier] :
              var.cloud_provider == "aws" ? local.aws_volume_types[var.tier] :
              var.cloud_provider == "alibaba" ? local.alibaba_disk_types[var.tier] :
              "unknown"
}
```

---

## Naming Conventions

### Deterministic Naming Pattern

```hcl
# modules/shared/naming.tf
locals {
  # Deterministic suffix from content hash
  name_suffix = substr(sha256("${var.project_name}${var.environment}${var.cloud_provider}${var.region}"), 0, 6)
  
  # Standard name components
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Resource naming conventions
  naming_convention = {
    # Azure: {prefix}-{type}-{suffix}
    azure = {
      resource_group = "${local.name_prefix}-rg-${local.name_suffix}"
      vnet           = "${local.name_prefix}-vnet-${local.name_suffix}"
      subnet         = "${local.name_prefix}-subnet-${local.name_suffix}"
      nsg            = "${local.name_prefix}-nsg-${local.name_suffix}"
      vm             = "${local.name_prefix}-vm-${local.name_suffix}"
      disk           = "${local.name_prefix}-disk-${local.name_suffix}"
      key_vault      = "${local.name_prefix}-kv-${local.name_suffix}"
      storage        = "${local.name_prefix}st${local.name_suffix}"  # No dashes allowed
    }
    
    # AWS: {prefix}-{type}-{suffix}
    aws = {
      vpc            = "${local.name_prefix}-vpc-${local.name_suffix}"
      subnet         = "${local.name_prefix}-subnet-${local.name_suffix}"
      security_group = "${local.name_prefix}-sg-${local.name_suffix}"
      instance       = "${local.name_prefix}-ec2-${local.name_suffix}"
      volume         = "${local.name_prefix}-vol-${local.name_suffix}"
      iam_role       = "${local.name_prefix}-role-${local.name_suffix}"
      key_pair       = "${local.name_prefix}-key-${local.name_suffix}"
      s3_bucket      = "${local.name_prefix}-s3-${local.name_suffix}"
    }
    
    # Alibaba: {prefix}-{type}-{suffix}
    alibaba = {
      vpc            = "${local.name_prefix}-vpc-${local.name_suffix}"
      vswitch        = "${local.name_prefix}-vsw-${local.name_suffix}"
      security_group = "${local.name_prefix}-sg-${local.name_suffix}"
      instance       = "${local.name_prefix}-ecs-${local.name_suffix}"
      disk           = "${local.name_prefix}-disk-${local.name_suffix}"
      ram_role       = "${local.name_prefix}-role-${local.name_suffix}"
      key_pair       = "${local.name_prefix}-key-${local.name_suffix}"
      oss_bucket     = "${local.name_prefix}-oss-${local.name_suffix}"
    }
  }
}
```

---

## Module Composition Patterns

### Pattern 1: Layered Composition

```hcl
# environments/lab/aws/main.tf
module "network" {
  source = "../../modules/platform/network/aws"
  
  name       = local.name_prefix
  cidr_block = var.network_cidr
  subnets    = var.subnets
  tags       = local.common_tags
}

module "compute" {
  source = "../../modules/platform/compute/aws"
  
  name              = local.name_prefix
  tier              = var.tier
  instance_count    = var.instance_count
  subnet_id         = module.network.subnet_ids["main"]
  security_group_ids = [module.network.security_group_ids["main"]]
  user_data         = local.cloud_init_config
  tags              = local.common_tags
}

module "external_ca" {
  source = "../../modules/platform/external-ca"
  
  name         = local.name_prefix
  ca_type      = var.ca_type
  tier         = var.tier
  trust_domain = var.trust_domain
  tags         = local.common_tags
}
```

### Pattern 2: Conditional Composition

```hcl
# Only deploy CA if enabled
module "external_ca" {
  count = var.enable_external_ca ? 1 : 0
  
  source = "../../modules/platform/external-ca"
  # ...
}

# Only deploy monitoring if enabled
module "monitoring" {
  count = var.enable_monitoring ? 1 : 0
  
  source = "../../modules/platform/monitoring"
  # ...
}
```

### Pattern 3: Multi-Cloud Composition

```hcl
# Deploy to multiple clouds with same configuration
module "aws_infrastructure" {
  source = "../../modules/platform"
  
  cloud_provider = "aws"
  region         = var.aws_region
  # ...
}

module "azure_infrastructure" {
  source = "../../modules/platform"
  
  cloud_provider = "azure"
  region         = var.azure_region
  # ...
}

module "alibaba_infrastructure" {
  source = "../../modules/platform"
  
  cloud_provider = "alibaba"
  region         = var.alibaba_region
  # ...
}
```

---

## Idempotency Patterns

### 1. Data Source Over Resource

```hcl
# Use data sources for existing resources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Instead of creating new AMIs
```

### 2. Lifecycle Rules

```hcl
resource "aws_instance" "main" {
  # ...
  
  lifecycle {
    ignore_changes = [
      user_data,
      ami,
      tags["CreatedAt"],
    ]
    
    create_before_destroy = true
  }
}
```

### 3. Deterministic Naming

```hcl
# Use content hash instead of random
locals {
  name_suffix = substr(sha256("${var.project_name}${var.environment}"), 0, 6)
}

# Instead of random_string
```

### 4. Idempotent Bootstrap Scripts

```bash
#!/bin/bash
# Cloud-init script should be idempotent

# Check if already installed
if command -v k3s &> /dev/null; then
  echo "K3s already installed, skipping"
  exit 0
fi

# Install
curl -sfL https://get.k3s.io | sh -
```

### 5. State Locking

```hcl
# Always use remote state with locking
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "path/to/state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

---

## Validation and Testing

### Contract Validation

```hcl
# modules/platform/network/tests/contract.tftest.hcl
run "validate_network_contract" {
  command = plan
  
  variables {
    name       = "test"
    cidr_block = "10.0.0.0/16"
    subnets = {
      main = "10.0.1.0/24"
    }
  }
  
  assert {
    condition     = output.network_id != ""
    error_message = "network_id must not be empty"
  }
  
  assert {
    condition     = length(output.subnet_ids) > 0
    error_message = "subnet_ids must not be empty"
  }
}
```

### Provider-Specific Tests

```hcl
# modules/platform/network/aws/tests/aws.tftest.hcl
run "validate_aws_network" {
  command = plan
  
  variables {
    name       = "test"
    cidr_block = "10.0.0.0/16"
    subnets = {
      main = "10.0.1.0/24"
    }
  }
  
  assert {
    condition     = can(regex("^vpc-", output.network_id))
    error_message = "AWS network_id must be a VPC ID"
  }
}
```

---

## Summary

| Contract | Purpose | Key Outputs |
|----------|---------|-------------|
| **network** | VPC/VNet, subnets, routing, security groups | network_id, subnet_ids, security_group_ids |
| **compute** | VMs/Instances, disks, SSH access | instance_ids, private_ips, public_ips |
| **external-ca** | CA infrastructure, certificates, enrollment | ca_certificates, enrollment_urls, ocsp_url |
| **storage** | Object storage, block storage | bucket_names, volume_ids |
| **identity** | IAM, service accounts, roles | role_arns, service_account_ids |
| **secrets** | Secret management, key storage | secret_ids, key_ids |

---

## Next Steps

1. Implement provider adapters for each contract
2. Create comprehensive test suites
3. Build CI/CD pipelines for validation
4. Document provider-specific quirks and limitations
5. Create migration guides for existing infrastructure
