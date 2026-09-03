# AWS Terraform Module

## Overview

This module provisions a minimal AWS environment for running K3s and the Machine Identity Platform.

## Resources Created

| Resource | Type | Purpose |
|----------|------|---------|
| VPC | `aws_vpc` | Network isolation |
| Internet Gateway | `aws_internet_gateway` | Internet access |
| Subnet | `aws_subnet` | Public subnet |
| Route Table | `aws_route_table` | Routing |
| Security Group | `aws_security_group` | Firewall rules |
| IAM Role | `aws_iam_role` | EC2 permissions |
| IAM Instance Profile | `aws_iam_instance_profile` | Role attachment |
| EC2 Instance | `aws_instance` | K3s host |

## Usage

```bash
cd infra/terraform/aws

# Initialize
terraform init

# Validate
terraform validate

# Plan (PLAN-ONLY by default)
terraform plan -out=aws.tfplan

# DO NOT APPLY without Cost Auditor approval
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `environment` | Environment name | `aws` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `key_name` | AWS key pair name | (required) |
| `ssh_public_key` | SSH public key | (required) |
| `vpc_cidr` | VPC CIDR | `10.1.0.0/16` |
| `subnet_cidr` | Subnet CIDR | `10.1.1.0/24` |
| `root_volume_size` | Root volume size (GB) | `20` |
| `allowed_ssh_cidr` | Allowed SSH CIDR | `0.0.0.0/0` |

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `subnet_id` | Subnet ID |
| `instance_id` | EC2 instance ID |
| `instance_public_ip` | Public IP address |
| `instance_private_ip` | Private IP address |
| `ssh_command` | SSH connection command |
| `k3s_kubeconfig` | Kubeconfig copy command |

## Cost

Estimated monthly cost:
- Free Tier: $0 (12 months)
- Post Free-Tier: ~$17/month

No resources will be created without explicit approval.
