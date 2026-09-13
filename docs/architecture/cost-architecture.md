# Cost Architecture

## Overview

This document defines the cost architecture for the Machine Identity Platform. Cost control is built into every tier, with guardrails to prevent accidental high-cost deployments.

---

## Cost Principles

1. **Tier-driven cost** — Economy minimizes cost, Standard balances cost and reliability, Enterprise prioritizes reliability over cost
2. **Explicit high-cost services** — NAT Gateway, managed Kubernetes, managed databases, load balancers, HSM are always explicit choices
3. **Cost guardrails** — Pre-apply validation stops unexpected resource creation
4. **Cost estimation** — Every plan includes a cost estimate before apply
5. **Cost monitoring** — Ongoing cost tracking and alerting

---

## Tier Cost Profiles

### Economy Tier

**Goal:** Lowest reasonable customer cost

| Resource | Azure | AWS | Alibaba | Monthly Cost (USD) |
|----------|-------|-----|---------|-------------------|
| Compute | Standard_B2s (2 vCPU, 4GB) | t3.small (2 vCPU, 2GB) | ecs.t6-c1m2.large (2 vCPU, 4GB) | ~$15-30 |
| Disk | StandardSSD_LRS 30GB | gp3 30GB | cloud_efficiency 30GB | ~$2-5 |
| Database | Container (PostgreSQL) | Container (PostgreSQL) | Container (PostgreSQL) | $0 |
| Load Balancer | None | None | None | $0 |
| Managed K8s | No | No | No | $0 |
| NAT Gateway | No | No | No | $0 |
| Public IP | Optional (disabled) | Optional (disabled) | Optional (disabled) | $0-4 |
| Object Storage | None | None | None | $0 |
| **Total** | | | | **~$17-39** |

### Standard Tier

**Goal:** Mid-market production architecture

| Resource | Azure | AWS | Alibaba | Monthly Cost (USD) |
|----------|-------|-----|---------|-------------------|
| Compute | Standard_D2s_v5 ×2-3 (2 vCPU, 8GB) | t3.medium ×2-3 (2 vCPU, 4GB) | ecs.g7.large ×2-3 (2 vCPU, 8GB) | ~$60-150 |
| Disk | Premium_LRS 50GB ×2-3 | gp3 50GB ×2-3 | cloud_essd 50GB ×2-3 | ~$10-25 |
| Database | Azure Database for PostgreSQL Flexible (Burstable) | RDS PostgreSQL (db.t3.micro) | ApsaraDB RDS PostgreSQL (basic) | ~$15-50 |
| Load Balancer | Azure LB (basic) | NLB | SLB | ~$15-25 |
| Managed K8s | No (K3s multi-node) | No (K3s multi-node) | No (K3s multi-node) | $0 |
| NAT Gateway | Optional | Optional | Optional | $0-35 |
| Public IP | 1 (for LB) | 1 (for LB) | 1 (for LB) | ~$4 |
| Object Storage | Blob Storage (if needed) | S3 (if needed) | OSS (if needed) | ~$0-10 |
| **Total** | | | | **~$104-299** |

### Enterprise Tier

**Goal:** High availability, strong isolation, maximum operational resilience

| Resource | Azure | AWS | Alibaba | Monthly Cost (USD) |
|----------|-------|-----|---------|-------------------|
| Compute | Standard_D4s_v5 ×3+ (4 vCPU, 16GB) | m6i.large ×3+ (2 vCPU, 8GB) | ecs.g7.xlarge ×3+ (4 vCPU, 16GB) | ~$200-500 |
| Disk | Premium_LRS 100GB+ ×3+ | gp3 100GB+ ×3+ | cloud_essd 100GB+ ×3+ | ~$30-75 |
| Database | Azure Database for PostgreSQL Flexible (HA) | RDS PostgreSQL (Multi-AZ) | ApsaraDB RDS PostgreSQL (HA) | ~$100-300 |
| Load Balancer | Azure LB / App GW | NLB / ALB | SLB / NLB | ~$20-150 |
| Managed K8s | Optional (AKS) | Optional (EKS) | Optional (ACK) | $0-75 |
| NAT Gateway | Yes (if private subnets) | Yes (if private subnets) | Yes (if private subnets) | ~$30-35 |
| Public IP | Multiple | Multiple | Multiple | ~$10-20 |
| Object Storage | Blob Storage (GRS) | S3 (versioned) | OSS (versioned) | ~$10-50 |
| HSM | Optional (Dedicated HSM) | Optional (CloudHSM) | Optional (Cloud HSM) | $0-1000+ |
| WAF | Optional (App GW WAF) | Optional (AWS WAF) | Optional (WAF) | $0-150 |
| **Total** | | | | **~$400-2355+** |

---

## Cost Traps

### High-Cost Services to Avoid in Economy

| Service | Azure | AWS | Alibaba | Monthly Cost | Why Avoid |
|---------|-------|-----|---------|--------------|-----------|
| Managed K8s | AKS (~$70/mo) | EKS (~$72/mo) | ACK (~$60/mo) | $60-75 | K3s is free |
| NAT Gateway | ~$32/mo + data | ~$32/mo + data | ~$30/mo + data | $30-50 | Use IGW + public IP |
| Managed DB | ~$25-200/mo | ~$15-200/mo | ~$15-200/mo | $15-200 | Use container PostgreSQL |
| Load Balancer | ~$18/mo (LB) | ~$16/mo (NLB) | ~$15/mo (SLB) | $15-20 | Use NodePort |
| HSM | ~$1,000+/mo | ~$1,000+/mo | ~$800+/mo | $800-1000+ | Use OpenBao |
| WAF | ~$125/mo (App GW) | ~$22/mo (ALB) | ~$15/mo (SLB) | $15-125 | Use NetworkPolicy |

### Data Transfer Costs

| Provider | Inbound | Outbound | Notes |
|----------|---------|----------|-------|
| Azure | Free | ~$0.05-0.12/GB | First 5GB free |
| AWS | Free | ~$0.09/GB | First 1GB free |
| Alibaba | Free | ~$0.08/GB | First 1GB free |

---

## Cost Guardrails

### Pre-Apply Validation

Before every `terraform apply`, the pipeline must output:

```
==============================================
COST GUARDRAIL VALIDATION
==============================================

Customer: contoso
Provider: azure
Tier: standard
Environment: prod

EXPECTED MONTHLY COST: ~$150

RESOURCE BREAKDOWN:
- Compute (3 VMs): ~$90
- Database (managed): ~$30
- Load Balancer: ~$20
- Storage: ~$10
- Public IP: ~$4
- Total: ~$154

COST LIMIT: $500
APPROVAL REQUIRED ABOVE: $200

VALIDATION: PASS
```

### Hard Stops

| Tier | Resource | Max | Action if Exceeded |
|------|----------|-----|-------------------|
| Economy | Total monthly cost | $50 | STOP |
| Economy | VMs | 2 | STOP |
| Economy | Public IPs | 1 | STOP |
| Economy | NAT Gateways | 0 | STOP |
| Economy | Managed K8s | 0 | STOP |
| Economy | Managed DB | 0 | STOP |
| Standard | Total monthly cost | $300 | STOP |
| Standard | VMs | 5 | STOP |
| Standard | Load Balancers | 2 | STOP |
| Enterprise | Total monthly cost | $2000 | REVIEW |
| Enterprise | VMs | 10 | REVIEW |

### Approval Gates

| Cost Threshold | Approver | Criteria |
|---------------|----------|----------|
| $0-200 | Automatic | Within tier limits |
| $200-500 | Team lead | Above economy, within standard |
| $500-1000 | Security team | Above standard, within enterprise |
| $1000+ | Management | Above enterprise |

---

## Cost Monitoring

### Ongoing Cost Tracking

| Tool | Purpose | Frequency |
|------|---------|-----------|
| Azure Cost Management | Track Azure costs | Daily |
| AWS Cost Explorer | Track AWS costs | Daily |
| Alibaba Cost Center | Track Alibaba costs | Daily |
| Prometheus | Track resource usage | Real-time |
| Grafana | Visualize cost trends | Real-time |

### Cost Alerts

| Alert | Condition | Action |
|-------|-----------|--------|
| `CostExceedsBudget` | Monthly cost > budget | Notify team |
| `CostSpike` | Daily cost > 2x average | Notify team |
| `UnexpectedResource` | New high-cost resource created | Notify team |
| `IdleResource` | Resource unused for 7 days | Notify team |

---

## Cost Optimization

### Recommendations by Tier

| Tier | Recommendation | Savings |
|------|---------------|---------|
| Economy | Use spot instances | ~50-70% |
| Economy | Use burstable VMs | ~30-50% |
| Economy | Disable public IP | ~$4/mo |
| Standard | Use reserved instances | ~30-40% |
| Standard | Use savings plans | ~20-30% |
| Enterprise | Use committed use discounts | ~20-40% |
| Enterprise | Use enterprise agreements | ~10-30% |

### Resource Cleanup

| Resource | Cleanup Policy | Frequency |
|----------|---------------|-----------|
| Unused VMs | Stop after 7 days | Weekly |
| Unused disks | Delete after 30 days | Monthly |
| Unused public IPs | Release after 7 days | Weekly |
| Old snapshots | Delete after 90 days | Monthly |
| Unused load balancers | Delete after 7 days | Weekly |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial cost architecture |
