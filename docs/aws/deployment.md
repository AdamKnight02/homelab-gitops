# AWS Deployment Guide

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **AWS Account** | Active account with appropriate permissions |
| **AWS CLI** | v2.x, configured with credentials |
| **Terraform** | >= 1.10.0, < 2.0.0 |
| **IAM Permissions** | EC2, VPC, IAM, RDS, S3, KMS, Secrets Manager, ELB |
| **Git Repository** | GitOps repo URL for Argo CD |

### Verify AWS Authentication

```bash
aws sts get-caller-identity
# Expected: Account 962500057493, User AdamKnight
```

### Required IAM Permissions

The deploying user/role needs permissions for:

- **EC2**: Create/manage instances, volumes, key pairs, security groups
- **VPC**: Create/manage VPCs, subnets, route tables, IGWs, NAT gateways, EIPs
- **IAM**: Create/manage roles, policies, instance profiles
- **RDS**: Create/manage DB instances, subnet groups, parameter groups
- **S3**: Create/manage buckets, lifecycle policies, encryption
- **KMS**: Create/manage keys, aliases
- **Secrets Manager**: Create/manage secrets
- **ELB**: Create/manage load balancers, target groups, listeners
- **SSM**: Session Manager access (for instance management)

---

## Quick Start

### 1. Configure Variables

```bash
cd infra/terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# Minimal configuration (economy tier, defaults)
service_tier = "economy"

# Optional: Enable SSH access from your IP
# allow_ssh_cidr = ["203.0.113.50/32"]

# Optional: Enable public IP (adds ~$3.60/month)
# aws_associate_public_ip = true
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review Plan (Cost Guardrail)

```bash
terraform plan
```

**Review the `cost_guardrail_summary` output before proceeding:**

```
=== COST GUARDRAIL SUMMARY (ECONOMY tier) ===
EC2 Instances:    1
EBS Volumes:      1 (20 GB)
NAT Gateways:     0
Public IPs:       0
RDS Instances:    0
EKS Clusters:     0
Load Balancers:   0
S3 Buckets:       0
KMS Keys:         0
Secrets Manager:  0

Estimated Monthly Cost: ~$10.10
==============================================
```

**Verify for Economy tier:**
- ✅ NAT Gateways = 0
- ✅ RDS Instances = 0
- ✅ EKS Clusters = 0
- ✅ Load Balancers = 0

### 4. Apply

```bash
terraform apply
```

### 5. Retrieve Outputs

```bash
# Get SSH private key (save securely)
terraform output -raw ssh_private_key > ~/.ssh/pki-aws-key.pem
chmod 600 ~/.ssh/pki-aws-key.pem

# Get instance details
terraform output instance_id
terraform output instance_private_ip
terraform output instance_public_ip  # If public IP enabled

# Get cost summary
terraform output cost_guardrail_summary
```

---

## Tier-Specific Deployments

### Economy Tier (Default)

**Use case:** Development, testing, proof-of-concept, homelab.

```hcl
# terraform.tfvars
service_tier = "economy"
```

**What gets created:**
- 1 VPC, 1 public subnet, 1 IGW
- 1 security group (SSH optional, all outbound)
- 1 EC2 t3.micro instance
- 1 IAM role (SSM + CloudWatch read-only)
- 1 SSH key pair

**Access:**
```bash
# Via SSM Session Manager (no public IP needed)
aws ssm start-session --target <instance-id>

# Via SSH (if public IP enabled)
ssh -i ~/.ssh/pki-aws-key.pem ubuntu@<public-ip>
```

**Retrieve K3s kubeconfig:**
```bash
# Via SSM
aws ssm start-session --target <instance-id> \
  --document-name AWS-StartInteractiveCommand \
  --parameters command='sudo cat /etc/rancher/k3s/k3s.yaml'

# Via SSH
ssh -i ~/.ssh/pki-aws-key.pem ubuntu@<public-ip> \
  'sudo cat /etc/rancher/k3s/k3s.yaml'
```

---

### Standard Tier

**Use case:** Production, small-to-medium enterprise.

```hcl
# terraform.tfvars
service_tier = "standard"
```

**What gets created (in addition to economy):**
- 3 EC2 t3.medium instances (1 K3s server + 2 agents)
- Network Load Balancer (ports 80, 443, 6443)
- RDS PostgreSQL db.t3.micro (single-AZ)
- S3 bucket for backups
- Enhanced IAM policies (S3, EBS CSI, CloudWatch Agent)
- Additional security groups (LB, RDS)

**Access:**
```bash
# K3s API via NLB
terraform output k3s_api_endpoint
# https://<nlb-dns-name>:6443

# RDS endpoint
terraform output db_endpoint

# S3 bucket
terraform output s3_bucket_id
```

**Retrieve K3s kubeconfig:**
```bash
# SSH to server node (first instance)
ssh -i ~/.ssh/pki-aws-key.pem ubuntu@<server-ip> \
  'sudo cat /etc/rancher/k3s/k3s.yaml'
```

---

### Enterprise Tier

**Use case:** Mission-critical, regulated industries.

```hcl
# terraform.tfvars
service_tier = "enterprise"
```

**What gets created (in addition to standard):**
- 6 EC2 m6i.large instances across 3 AZs
- 3 public + 3 private subnets
- 3 NAT Gateways (one per AZ)
- RDS PostgreSQL db.r6g.large (Multi-AZ)
- S3 bucket with versioning + KMS encryption
- KMS key (auto-rotating)
- Secrets Manager (DB credentials, OpenBao unseal keys)
- Enhanced monitoring and logging
- Deletion protection on critical resources

**Access:**
```bash
# K3s API via NLB (cross-zone)
terraform output k3s_api_endpoint

# RDS endpoint (Multi-AZ)
terraform output db_endpoint

# KMS key
terraform output kms_key_arn

# Database credentials (in Secrets Manager)
aws secretsmanager get-secret-value \
  --secret-id pki/db/credentials-<suffix>
```

---

## Post-Deployment

### Verify K3s Cluster

```bash
# Set kubeconfig
export KUBECONFIG=<path-to-kubeconfig>

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check Argo CD
kubectl get pods -n argocd
```

### Access Argo CD

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Port forward (economy)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access via NLB (standard/enterprise)
# https://<nlb-dns-name>/argocd
```

### Verify Database (Standard/Enterprise)

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier pki-pg-<suffix>

# Test connection from K3s node
psql "postgresql://pkiadmin:<password>@<rds-endpoint>/pki"
```

### Verify S3 Backups (Standard/Enterprise)

```bash
# List backups
aws s3 ls s3://pki-backups-<suffix>/etcd/

# Check lifecycle policy
aws s3api get-bucket-lifecycle-configuration \
  --bucket pki-backups-<suffix>
```

---

## Cost Management

### Before Apply

Always review the cost guardrail:

```bash
terraform plan -out=tfplan
terraform show -json tfplan | jq '.planned_values.outputs.cost_guardrail_summary'
```

### After Apply

```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2026-09-01,End=2026-09-30 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Project
```

### Cost Optimization Tips

| Action | Savings | Impact |
|--------|---------|--------|
| Disable public IPs | ~$3.60/instance/month | Use SSM instead |
| Use economy tier | ~$130-640/month | Single node, no HA |
| Stop instances when not in use | ~60-70% of EC2 cost | Manual start/stop |
| Use t3.micro (economy) | Free tier eligible | 750 hours/month free |
| Reduce EBS volume size | ~$0.08/GB/month | Minimum 8 GB |

### Cleanup

```bash
# Destroy all resources
terraform destroy

# Verify cleanup
aws ec2 describe-instances --filters "Name=tag:Project,Values=pki-cloudlab"
aws rds describe-db-instances --filters "Name=tag:Project,Values=pki-cloudlab"
aws s3 ls | grep pki
```

---

## Troubleshooting

### Common Issues

**Issue: `terraform init` fails with module not found**
```
Solution: Ensure you're in the infra/terraform/aws directory.
The module source paths are relative (../modules/aws/*).
```

**Issue: `terraform validate` fails with template variable error**
```
Solution: Ensure all template variables are passed in the
templatefile() call. The name_prefix variable was previously
missing from the agent template — this has been fixed.
```

**Issue: EC2 instance not reachable via SSH**
```
Solution: Check that:
1. allow_ssh_cidr includes your IP
2. aws_associate_public_ip = true
3. Security group allows port 22 from your CIDR
```

**Issue: K3s agent not joining cluster (standard/enterprise)**
```
Solution: Agents retrieve the K3s token from SSM Parameter Store.
Ensure the server has written the token to SSM:
  aws ssm get-parameter --name "/k3s/pki/node-token"
If missing, SSH to the server and check:
  sudo cat /var/lib/rancher/k3s/server/node-token
```

**Issue: RDS not accessible from K3s (standard/enterprise)**
```
Solution: Check that:
1. RDS security group allows port 5432 from K3s security group
2. RDS is in the correct subnet group
3. Database mode is not "container" for this tier
```

### Useful Commands

```bash
# Check instance status
aws ec2 describe-instances --instance-ids <id>

# View cloud-init logs
aws ssm start-session --target <id> \
  --document-name AWS-StartInteractiveCommand \
  --parameters command='sudo cat /var/log/cloud-init-output.log'

# Check K3s status
ssh -i ~/.ssh/pki-aws-key.pem ubuntu@<ip> 'sudo systemctl status k3s'

# View K3s logs
ssh -i ~/.ssh/pki-aws-key.pem ubuntu@<ip> 'sudo journalctl -u k3s -f'

# Check RDS status
aws rds describe-db-instances --db-instance-identifier <id>

# View NLB status
aws elbv2 describe-load-balancers --names pki-nlb-<suffix>
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | AWS Provider Engineer | Initial AWS deployment guide |
