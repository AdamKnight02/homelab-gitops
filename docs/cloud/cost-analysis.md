# Cost Analysis — Multi-Cloud PKI Lab

> **Status**: PLAN-ONLY for both clouds  
> **Actual Project Cost**: $0  

## Azure Cost Analysis

### If Deployed (Estimated Monthly)

| Resource | SKU | Cost/Month |
|----------|-----|------------|
| Linux VM | Standard_B1s | ~$8.50 |
| OS Disk | 30GB Standard SSD | ~$1.50 |
| Data Disk | 50GB Standard SSD | ~$2.50 |
| Public IP | Dynamic Basic | $0 |
| **Total** | | **~$12.50/month** |

### Cost Optimization

- **Stop VM when not in use**: Compute cost drops to $0
- **Dynamic IP**: No charge when VM is stopped
- **Standard SSD**: 2x cheaper than Premium SSD
- **No managed services**: Self-managed K3s vs AKS

### Cost Traps Avoided

| Service | Monthly Cost | Avoided By |
|---------|-------------|------------|
| AKS | $70+ | Using K3s on VM |
| Azure Database for PostgreSQL | $15+ | Self-managed PostgreSQL |
| Azure Key Vault | $5+ | Self-managed OpenBao |
| Load Balancer (Standard) | $18 | Using NodePort |
| Application Gateway | $25+ | Using NodePort |
| NAT Gateway | $32 | Public subnet with IGW |
| Static Public IP | $3.60 | Dynamic IP |
| Premium SSD | $10+ | Standard SSD |
| Log Analytics | Variable | Not enabled |

## AWS Cost Analysis

### If Deployed (Estimated Monthly)

| Resource | SKU | Cost/Month |
|----------|-----|------------|
| EC2 Instance | t2.micro | **FREE** (750 hrs/mo) |
| Root EBS | 20GB gp2 | **FREE** (30GB/mo) |
| Data EBS | 30GB gp2 | ~$3.00 |
| Public IP | Dynamic | $0 |
| **Total (Free Tier)** | | **~$3.00/month** |
| **Total (After Free Tier)** | | **~$13.50/month** |

### Free Tier Eligibility

| Resource | Free Tier Allowance | Used |
|----------|---------------------|------|
| t2.micro | 750 hours/month | 720 hours/month |
| EBS (gp2) | 30GB/month | 20GB |
| Data transfer | 15GB/month | ~5GB |

### Cost Optimization

- **Stop instance when not in use**: Compute cost drops to $0
- **gp2 instead of gp3**: Sufficient for lab workloads
- **No Elastic IP**: Dynamic IP is free
- **No NAT Gateway**: Public subnet with IGW

### Cost Traps Avoided

| Service | Monthly Cost | Avoided By |
|---------|-------------|------------|
| EKS | $70+ | Using K3s on EC2 |
| NAT Gateway | $32 | Public subnet with IGW |
| RDS | $15+ | Self-managed PostgreSQL |
| ALB/NLB | $20+ | Using NodePort |
| Elastic IP | $3.60 | Dynamic IP |
| CloudWatch Logs | Variable | Minimal logging |
| ECR | Variable | Using public registry |
| Data transfer | Variable | Minimal outbound |

## Comparison Summary

| Metric | Azure | AWS |
|--------|-------|-----|
| **Plan Cost** | $0 | $0 |
| **Deploy Cost (Free Tier)** | ~$12.50/mo | ~$3.00/mo |
| **Deploy Cost (After Free Tier)** | ~$12.50/mo | ~$13.50/mo |
| **Free Tier Available** | No | Yes |
| **VM Size** | 1 vCPU, 1 GB | 1 vCPU, 1 GB |
| **Storage** | 80GB Standard SSD | 50GB gp2 |
| **Network** | VNet + NSG | VPC + Security Group |

## Key Takeaways

1. **Both clouds are affordable for a lab**: <$15/month each
2. **AWS has free tier advantage**: 12 months of free compute
3. **Azure has consistent pricing**: No free tier, but predictable
4. **Stopping VMs when not in use** reduces cost to ~$3-5/month (storage only)
5. **Avoiding managed services** saves $50-100/month per cloud
