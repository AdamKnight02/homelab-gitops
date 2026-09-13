# Azure Architecture

> **Execution Mode**: PLAN-ONLY  
> **Estimated Cost if Deployed**: ~$12.50/month  
> **Actual Project Cost**: $0

## Design Decisions

### Why VM + K3s instead of AKS?

| Factor | VM + K3s | AKS |
|--------|----------|-----|
| Cost | ~$12.50/month | ~$70+/month |
| Complexity | Low | Medium |
| Portability | High (same as homelab) | Low (Azure-specific) |
| Learning Value | High | Medium |
| Control | Full | Managed |

### Why Standard_B1s?

- **Cheapest burstable VM** in Azure
- Sufficient for K3s + lightweight workloads
- Can be stopped when not in use (no compute cost)

### Why Dynamic Public IP?

- **$0 when VM is deallocated**
- Static IP costs ~$3.60/month even when unused
- Acceptable for a lab environment

## Resources

| Resource | SKU | Purpose |
|----------|-----|---------|
| Resource Group | — | Resource container |
| Virtual Network | — | Private networking (10.0.0.0/16) |
| Subnet | — | IP range (10.0.1.0/24) |
| NSG | — | Firewall rules |
| Public IP | Basic, Dynamic | External access |
| Network Interface | — | VM network attachment |
| Linux VM | Standard_B1s | Compute |
| OS Disk | 30GB Standard SSD | Boot disk |
| Data Disk | 50GB Standard SSD | K3s persistent storage |

## Network Security

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | User IP | SSH |
| 80 | TCP | Any | HTTP |
| 443 | TCP | Any | HTTPS |
| 6443 | TCP | VNet | K3s API |
| 30000-32767 | TCP | Any | K3s NodePorts |

## Bootstrap Process

1. Terraform creates infrastructure
2. VM boots with cloud-init
3. cloud-init installs Docker
4. cloud-init installs K3s
5. cloud-init installs kubectl, Helm, Argo CD CLI
6. Helm installs Argo CD
7. Argo CD syncs GitOps applications
8. PKI platform is deployed

## Cost Traps Avoided

- AKS (~$70+/month)
- Azure Database for PostgreSQL (~$15+/month)
- Azure Key Vault (~$5+/month)
- Load Balancer Standard (~$18/month)
- Application Gateway (~$25+/month)
- NAT Gateway (~$32/month)
- Static Public IP (~$3.60/month)
- Premium SSD (~$5+/month)
- Log Analytics (variable)
