# AWS PKI Lab — Terraform Root Module

## Status: PLAN-ONLY (Pending Free-Tier Verification)

**NO AWS RESOURCES WILL BE CREATED until free-tier eligibility is confirmed.**

If eligibility cannot be verified, this module remains plan-only like Azure.

## Architecture

```
AWS Account
    |
    v
VPC (10.0.0.0/16)
    |
    v
Public Subnet (10.0.1.0/24)
    |
    v
Internet Gateway
    |
    v
Security Group (deny-all inbound)
    |
    v
EC2 (t3.micro, Ubuntu 22.04)
    |
    v
K3s (via cloud-init)
    |
    v
Argo CD (via cloud-init)
    |
    v
GitOps PKI Platform
```

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Compute | t3.micro | Free-tier eligible (if available); 2 vCPU, 1GB RAM |
| Kubernetes | K3s (not EKS) | Cost, portability, similarity to homelab |
| Public IP | Disabled by default | Cost ($3.60/mo since Feb 2024) and security |
| SSH Access | Key-only, no inbound by default | Use AWS Session Manager |
| Root Volume | gp3 20GB | Cheaper than gp2; free-tier includes 30GB |
| Network | Single public subnet, no NAT | Minimal cost; IGW only |
| IAM | Minimal role (SSM + CloudWatch read-only) | Principle of least privilege |

## Cost Traps Avoided

- ❌ EKS (managed Kubernetes) — $72+/month control plane
- ❌ RDS (managed PostgreSQL) — $15+/month
- ❌ NAT Gateway — $32+/month
- ❌ ALB/NLB — $16-22+/month
- ❌ Elastic IP (when attached to running instance) — free, but $3.60/mo when unattached
- ❌ Public IPv4 Address — $3.60/month (disabled by default)
- ❌ CloudWatch Logs — $0.50/GB ingested
- ❌ ECR storage — $0.10/GB/month
- ❌ Data transfer — $0.09/GB outbound

## Free-Tier Considerations

| Resource | Free Tier | Proposed | Status |
|----------|-----------|----------|--------|
| EC2 t3.micro | 750 hrs/month | 1 instance | ✅ Eligible if account qualifies |
| EBS gp3 | 30GB/month | 20GB | ✅ Within limit |
| Data transfer | 100GB out | Minimal | ✅ Likely within limit |
| Public IPv4 | Not free | Disabled | ✅ Avoided |

## Validation Commands

```bash
cd infra/terraform/aws
terraform init
terraform validate
terraform plan
```

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC identifier |
| `instance_id` | EC2 instance ID |
| `instance_private_ip` | Private IP for internal access |
| `estimated_monthly_cost_usd` | ~$10-14/month if deployed |

## Security Notes

- No public IP by default
- Security group denies all inbound traffic
- SSH key auto-generated (ED25519)
- IAM role has minimal permissions only
- All resources tagged for identification
