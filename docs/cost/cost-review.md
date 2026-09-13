# Cost Review — PKI Platform Expansion

**Reviewer:** Agent 12 (Cost/Capacity Reviewer v3)
**Date:** 2026-09-12
**Sources reviewed:**
- `docs/architecture/cost-architecture.md`
- `infra/terraform/modules/aws/tier-config.tf`

---

## 1. Tier Cost Summary

### Economy — ~$17–39/month

| Component | AWS Choice | Est. Cost |
|-----------|-----------|-----------|
| Compute | 1× t3.micro (2 vCPU, 1 GB) | ~$8.50 |
| Disk | 20 GB gp3 | ~$1.60 |
| Database | Container PostgreSQL (on-node) | $0 |
| Load Balancer | None (NodePort) | $0 |
| NAT Gateway | No | $0 |
| Managed K8s | No (K3s) | $0 |
| Public IP | Optional (default off) | $0–3.60 |
| S3 / KMS / Secrets Mgr | All disabled | $0 |
| **Terraform estimate** | | **~$10–14** |

> The architecture doc estimates $17–39 (using t3.small); the Terraform module uses the cheaper t3.micro, bringing the floor lower. Either way, well under the $50/mo hard stop.

### Standard — ~$104–299/month

| Component | AWS Choice | Est. Cost |
|-----------|-----------|-----------|
| Compute | 3× t3.medium (2 vCPU, 4 GB) | ~$90 |
| Disk | 3× 50 GB gp3 | ~$12 |
| Database | RDS PostgreSQL db.t3.micro (single-AZ) | ~$15 |
| Load Balancer | NLB | ~$16 |
| NAT Gateway | No | $0 |
| Managed K8s | No (K3s multi-node) | $0 |
| Public IP | 1 (for LB) | ~$3.60 |
| S3 | Enabled (no versioning) | ~$5 |
| KMS / Secrets Mgr | Disabled | $0 |
| **Terraform estimate** | | **~$141** |

> Within the $300/mo hard stop. The Terraform estimate (~$141) sits comfortably in the architecture doc's $104–299 range.

### Enterprise — ~$400–2,355+/month

| Component | AWS Choice | Est. Cost |
|-----------|-----------|-----------|
| Compute | 6× m6i.large (2 vCPU, 8 GB) | ~$420 |
| Disk | 6× 100 GB gp3 | ~$48 |
| Database | RDS PostgreSQL db.r6g.large Multi-AZ | ~$60 |
| Load Balancer | NLB (ALB optional) | ~$16 |
| NAT Gateway | 3 (one per AZ) | ~$96 |
| Private Subnets | Yes (3 AZ) | — |
| Managed K8s | Optional EKS (default off) | $0–72 |
| Public IPs | Multiple | ~$21.60 |
| S3 | Enabled with versioning | ~$5 |
| KMS | Enabled | ~$1 |
| Secrets Manager | Enabled | ~$0.40 |
| HSM | Optional (CloudHSM) | $0–1,000+ |
| **Terraform estimate** | | **~$668** |

> Within the $2,000/mo review threshold. HSM and EKS are opt-in variables, not defaults — they don't inflate the baseline.

---

## 2. Cost Traps Avoided

The architecture explicitly avoids these high-cost traps in lower tiers:

| Trap | Monthly Cost if Triggered | Avoided In | Mitigation |
|------|--------------------------|------------|------------|
| **Managed Kubernetes** (EKS) | ~$72 | Economy, Standard | K3s self-managed (free); EKS opt-in for Enterprise only |
| **NAT Gateway** | ~$32 + data transfer | Economy, Standard | Direct internet gateway + public IP; only Enterprise gets NAT |
| **Managed Database** (RDS) | ~$15–200 | Economy | Container PostgreSQL on the K3s node |
| **Load Balancer** (NLB/ALB) | ~$16 | Economy | NodePort direct access |
| **HSM** (CloudHSM) | ~$1,000+ | All tiers (default) | OpenBao software-based secrets; HSM is opt-in |
| **WAF** | ~$22–125 | All tiers (default) | Kubernetes NetworkPolicy |

---

## 3. Economy Tier Verification

Confirmed — the Economy tier does **NOT** include any of the following:

| Service | In Economy? | Evidence |
|---------|-------------|----------|
| NAT Gateway | ❌ No | `tier_nat_gateway.economy = false` |
| Managed Kubernetes (EKS) | ❌ No | `tier_eks_enabled.economy = false` |
| Managed Database (RDS) | ❌ No | `tier_database.economy = "container"` |
| Load Balancer (ALB/NLB) | ❌ No | `tier_load_balancer.economy = "none"` |
| HSM (CloudHSM) | ❌ No | Not in tier config; only an optional Enterprise add-on |
| Private Subnets | ❌ No | `tier_private_subnets.economy = false` |
| KMS | ❌ No | `tier_kms_enabled.economy = false` |
| Secrets Manager | ❌ No | `tier_secrets_manager.economy = false` |
| S3 | ❌ No | `tier_s3_enabled.economy = false` |
| CloudWatch Logs | ❌ No | `tier_cloudwatch_logs.economy = false` |
| Detailed Monitoring | ❌ No | `tier_detailed_monitoring.economy = false` |

**Verdict: PASS.** Economy tier is truly minimal — a single VM running K3s with container PostgreSQL and no managed services.

---

## 4. Terraform Cost Guardrails

The `tier-config.tf` module implements these guardrails:

### 4.1 Feature Flags (Tier-Driven)

Every high-cost resource is controlled by a tier lookup map. There is no way to accidentally create a NAT Gateway or RDS instance in Economy — the flags are hardcoded to `false`.

### 4.2 Cost Report Object

The `cost_report` local block produces a structured count of every billable resource:

```
EC2 instances, EBS volumes, NAT gateways, public IPs,
RDS instances, EKS clusters, load balancers, S3 buckets,
KMS keys, Secrets Manager entries
```

This can be consumed by CI/CD pipelines for pre-apply validation.

### 4.3 Estimated Monthly Cost

The `estimated_monthly_cost` local computes a rough dollar figure using inline pricing:

| Tier | Formula | Estimate |
|------|---------|----------|
| Economy | $8.50 + (1 × 20 GB × $0.08) | **~$10.10** |
| Standard | $90 + (3 × 50 × $0.08) + $15 + $16 + $5 | **~$138** |
| Enterprise | $420 + (6 × 100 × $0.08) + $96 + $60 + $16 + $5 + $1 + $0.40 | **~$646** |

### 4.4 Hard Stops (from architecture doc)

| Tier | Max Monthly Cost | Max VMs | Action |
|------|-----------------|---------|--------|
| Economy | $50 | 2 | STOP |
| Standard | $300 | 5 | STOP |
| Enterprise | $2,000 | 10 | REVIEW |

### 4.5 Approval Gates

| Estimated Cost | Approver |
|---------------|----------|
| $0–200 | Automatic |
| $200–500 | Team lead |
| $500–1,000 | Security team |
| $1,000+ | Management |

---

## 5. Observations

1. **Economy is genuinely cheap.** At ~$10–14/mo on AWS, it's suitable for evaluation and dev environments. The only variable is whether a public IP is attached.

2. **Standard hits the sweet spot.** ~$141/mo gets you 3-node K3s with RDS and an NLB — a reasonable production baseline for small-to-mid deployments.

3. **Enterprise defaults are sensible.** EKS and HSM are opt-in, not default. The ~$668/mo baseline covers multi-AZ with managed database and full monitoring.

4. **No hidden costs.** Every billable resource is explicitly mapped in the tier config. There are no implicit resources that could surprise.

5. **Minor discrepancy:** The architecture doc lists Economy compute as t3.small (~$15–30/mo) while the Terraform module uses t3.micro (~$8.50/mo). The Terraform is cheaper — this is a conservative discrepancy (actual cost lower than documented). Not a problem, but worth aligning.

---

## 6. Verdict

**APPROVED.** The cost architecture is well-designed with clear tier separation, explicit cost traps, and enforceable guardrails. The Terraform module faithfully implements the architecture with no gaps. Economy tier is verified free of all high-cost services.

---

*Review completed 2026-09-12 by Agent 12 (Cost/Capacity Reviewer v3).*
