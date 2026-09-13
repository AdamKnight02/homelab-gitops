# Alibaba Cloud Deployment Guide

## Overview

This guide covers deploying the Machine Identity Platform to Alibaba Cloud using Terraform. It includes prerequisites, configuration, deployment steps, and post-deployment verification.

**Current Status:** PLAN-ONLY — No Alibaba Cloud credentials are configured. This guide documents the process for when credentials become available.

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.10.0 | Infrastructure as Code |
| Alibaba Cloud CLI | >= 3.0 | Optional, for manual verification |
| kubectl | >= 1.28 | Kubernetes management (post-deploy) |

### Alibaba Cloud Account

1. **Create an Alibaba Cloud account** at https://www.alibabacloud.com
2. **Create an AccessKey pair:**
   - Go to RAM console → Users → Create User
   - Enable "OpenAPI" access
   - Save the AccessKey ID and AccessKey Secret
3. **Attach policies:**
   - `AliyunECSFullAccess` — ECS instance management
   - `AliyunVPCFullAccess` — VPC and networking
   - `AliyunRDSFullAccess` — Database (standard/enterprise)
   - `AliyunOSSFullAccess` — Object storage (standard/enterprise)
   - `AliyunKMSFullAccess` — Key management (enterprise)
   - `AliyunSLBFullAccess` — Load balancer (standard/enterprise)
   - `AliyunNLBFullAccess` — Network load balancer (standard/enterprise)
   - `AliyunRAMFullAccess` — Identity management

> **Security Note:** For production, create a custom policy with minimum required permissions instead of full access policies.

### Environment Variables

```bash
export ALICLOUD_ACCESS_KEY="your-access-key-id"
export ALICLOUD_SECRET_KEY="your-access-key-secret"
export ALICLOUD_REGION="cn-hangzhou"
```

---

## Configuration

### Step 1: Choose Your Tier

Create a `terraform.tfvars` file in `infra/terraform/alibaba/`:

```hcl
# Economy tier (default) — single node, minimal cost
service_tier = "economy"

# Standard tier — 3-node K3s, RDS, NLB, OSS
# service_tier = "standard"

# Enterprise tier — 6-node multi-zone, full HA
# service_tier = "enterprise"
```

### Step 2: Configure Networking

```hcl
alibaba_region     = "cn-hangzhou"
alibaba_vpc_cidr   = "10.0.0.0/16"
alibaba_subnet_cidr = "10.0.1.0/24"
```

### Step 3: Configure Access

```hcl
# SSH access (optional — key pair is auto-generated if not provided)
alibaba_ssh_public_key = "ssh-ed25519 AAAA..."

# Restrict SSH to specific CIDR blocks
allow_ssh_cidr = ["203.0.113.0/24"]

# Public IP (optional — disabled by default for cost)
alibaba_associate_public_ip = false
```

### Step 4: Configure Kubernetes

```hcl
k3s_version         = "v1.30"
argocd_version      = "v2.12"
git_repo_url        = "https://github.com/your-org/gitops-repo.git"
git_target_revision = "main"
```

### Step 5: Configure Tagging

```hcl
project_name = "pki-platform"
environment  = "production"
owner        = "platform-team"
cost_center  = "engineering"
```

---

## Deployment

### Step 1: Initialize Terraform

```bash
cd infra/terraform/alibaba
terraform init
```

### Step 2: Review the Plan

```bash
terraform plan
```

**Review the cost guardrail summary carefully:**

```
=== COST GUARDRAIL SUMMARY (ECONOMY tier) — Alibaba Cloud ===
ECS Instances:     1
Disks:             1 (30 GB)
NAT Gateways:      0
EIP Addresses:     0
Public IPs:        0
RDS Instances:     0
ACK Clusters:      0
Load Balancers:    0
OSS Buckets:       0
KMS Keys:          0
Secrets Manager:   0

Estimated Monthly Cost: ~$13.50
========================================================
```

**Economy Tier Checklist:**
- [ ] ECS Instances = 1
- [ ] NAT Gateways = 0
- [ ] RDS Instances = 0
- [ ] Load Balancers = 0
- [ ] ACK Clusters = 0
- [ ] Estimated cost < $20/month

### Step 3: Apply

```bash
terraform apply
```

### Step 4: Retrieve Outputs

```bash
# SSH private key (save securely)
terraform output -raw ssh_private_key > ~/.ssh/pki-alibaba
chmod 600 ~/.ssh/pki-alibaba

# Instance IP
terraform output instance_private_ip

# Cost report
terraform output cost_guardrail_summary
```

---

## Post-Deployment Verification

### Step 1: SSH to the Instance

```bash
ssh -i ~/.ssh/pki-alibaba root@<instance-ip>
```

### Step 2: Verify K3s

```bash
kubectl get nodes
kubectl get pods -A
```

### Step 3: Verify Argo CD

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Step 4: Verify Platform Components

```bash
# Check all namespaces
kubectl get namespaces

# Check PKI components
kubectl get pods -n pki
kubectl get pods -n openbao
kubectl get pods -n spire
kubectl get pods -n monitoring
```

---

## Tier-Specific Deployment Notes

### Economy Tier

- Single ECS instance with all components co-located
- No load balancer — access via NodePort or port-forward
- No managed database — PostgreSQL runs as container
- No public IP by default — use Alibaba Cloud Workbench for access

### Standard Tier

- 3 ECS instances (1 server, 2 agents)
- NLB for internal load balancing
- RDS PostgreSQL for database
- OSS bucket for backups
- CloudMonitor enabled

### Enterprise Tier

- 6 ECS instances across 3 zones
- NLB with internet-facing address
- RDS multi-zone HA
- OSS with versioning
- KMS encryption
- NAT Gateway + EIP for private subnet outbound
- Full monitoring stack

---

## Cleanup

### Destroy All Resources

```bash
terraform destroy
```

### Verify Cleanup

```bash
# Check for remaining resources
terraform show

# Verify no orphaned resources in Alibaba Cloud Console
# - ECS instances
# - VPCs
# - Security groups
# - RDS instances
# - OSS buckets
# - Load balancers
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `terraform init` fails | Provider not found | Check Terraform version >= 1.10.0 |
| `terraform plan` fails | No credentials | Set `ALICLOUD_ACCESS_KEY` and `ALICLOUD_SECRET_KEY` |
| Image not found | Region doesn't have Ubuntu 22.04 | Specify `image_id` explicitly |
| Zone not available | Zone doesn't support ECS | Specify `alibaba_zone_id` explicitly |
| RDS creation fails | Insufficient permissions | Attach `AliyunRDSFullAccess` policy |
| OSS bucket name conflict | Bucket names are globally unique | Change `name_prefix` |

### Debug Mode

```bash
# Enable Terraform debug logging
export TF_LOG=DEBUG
terraform plan 2>&1 | tee terraform-debug.log
```

### Static Validation (No Credentials)

```bash
# Validate syntax and configuration without credentials
terraform validate

# Format check
terraform fmt -check -recursive
```

---

## Security Checklist

Before deploying to production:

- [ ] SSH access restricted to specific CIDR blocks
- [ ] No public IPs on ECS instances (use bastion or Workbench)
- [ ] RAM role has minimum required permissions
- [ ] KMS encryption enabled (enterprise)
- [ ] OSS bucket is private (not public-read)
- [ ] Security group denies all inbound by default
- [ ] Terraform state is stored remotely with encryption
- [ ] SSH private key is stored securely (not in version control)
- [ ] Cost guardrail summary reviewed and approved
- [ ] All resources tagged for cost tracking

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Agent 6 (Alibaba Engineer) | Initial deployment guide |
