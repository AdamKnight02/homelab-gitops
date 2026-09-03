# AWS Architecture

> **Execution Mode**: PLAN-ONLY  
> **Estimated Cost if Deployed**: ~$3.00/month (after free tier)  
> **Free Tier Eligible**: YES (t2.micro + 20GB EBS)  
> **Actual Project Cost**: $0

## Design Decisions

### Why EC2 + K3s instead of EKS?

| Factor | EC2 + K3s | EKS |
|--------|-----------|-----|
| Cost | ~$3/month (after free tier) | ~$70+/month |
| Complexity | Low | High |
| Portability | High (same as homelab) | Low (AWS-specific) |
| Learning Value | High | Medium |
| Control | Full | Managed |

### Why t2.micro?

- **AWS Free Tier eligible** (750 hours/month for 12 months)
- Sufficient for K3s + lightweight workloads
- Can be stopped when not in use (no compute cost)

### Why No NAT Gateway?

- NAT Gateway costs ~$32/month
- Public subnet with IGW is sufficient for a lab
- All traffic goes directly through Internet Gateway

## Resources

| Resource | SKU | Purpose |
|----------|-----|---------|
| VPC | — | Private networking (10.1.0.0/16) |
| Internet Gateway | — | Internet access |
| Subnet | — | IP range (10.1.1.0/24) |
| Route Table | — | Traffic routing |
| Security Group | — | Firewall rules |
| IAM Role | — | EC2 permissions |
| IAM Instance Profile | — | Role attachment |
| EC2 Key Pair | — | SSH access |
| EC2 Instance | t2.micro | Compute |
| Root EBS | 20GB gp2 | Boot volume |
| Data EBS | 30GB gp2 | K3s persistent storage |

## Network Security

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | User IP | SSH |
| 80 | TCP | Any | HTTP |
| 443 | TCP | Any | HTTPS |
| 6443 | TCP | VPC | K3s API |
| 30000-32767 | TCP | Any | K3s NodePorts |

## Bootstrap Process

1. Terraform creates infrastructure
2. EC2 boots with cloud-init
3. cloud-init installs Docker
4. cloud-init installs K3s
5. cloud-init installs kubectl, Helm, Argo CD CLI
6. Helm installs Argo CD
7. Argo CD syncs GitOps applications
8. PKI platform is deployed

## Cost Traps Avoided

- EKS (~$70+/month)
- NAT Gateway (~$32/month)
- RDS (~$15+/month)
- ALB/NLB (~$20+/month)
- Elastic IP (~$3.60/month when unattached)
- CloudWatch Logs (variable)
- ECR (variable)
- Data transfer (variable)

## Free Tier Details

| Resource | Free Tier | Duration |
|----------|-----------|----------|
| t2.micro | 750 hours/month | 12 months |
| EBS (gp2) | 30GB/month | 12 months |
| Data transfer | 15GB/month | 12 months |

After free tier:
- t2.micro on-demand: ~$0.0116/hour = ~$8.50/month
- 20GB gp2 EBS: ~$2.00/month
- 30GB gp2 EBS (data): ~$3.00/month
