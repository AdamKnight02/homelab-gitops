# AWS Service Tiers

## Overview

This document describes how the provider-neutral service tiers (ECONOMY, STANDARD, ENTERPRISE) map to AWS-specific infrastructure decisions. For the platform-wide tier definitions, see [Service Tier Architecture](../architecture/service-tiers.md).

---

## Tier Selection

Set the `service_tier` variable in your `terraform.tfvars`:

```hcl
service_tier = "economy"    # Default — minimal cost
service_tier = "standard"   # Production-ready HA
service_tier = "enterprise" # Mission-critical, multi-AZ
```

---

## Tier-to-Resource Mapping

### Compute

| Attribute | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| **Instance Count** | 1 | 3 | 6 |
| **Instance Type** | t3.micro | t3.medium | m6i.large |
| **vCPUs (total)** | 2 | 6 | 12 |
| **RAM (total)** | 1 GB | 12 GB | 48 GB |
| **Root Volume** | 20 GB gp3 | 50 GB gp3 | 100 GB gp3 |
| **Detailed Monitoring** | No | Yes | Yes |
| **K3s Topology** | Single node | 1 server + 2 agents | 3 servers + 3 agents |

**Instance type override:**
```hcl
aws_instance_type_override = "t3.large"  # Overrides tier default
```

### Networking

| Attribute | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| **VPC** | 1 | 1 | 1 |
| **Availability Zones** | 1 | 1 | 3 |
| **Public Subnets** | 1 | 1 | 3 |
| **Private Subnets** | 0 | 0 | 3 |
| **NAT Gateway** | ❌ None | ❌ None | ✅ 3 (one per AZ) |
| **Internet Gateway** | 1 | 1 | 1 |
| **Route Tables** | 1 (public) | 1 (public) | 4 (1 public + 3 private) |

### Load Balancing

| Attribute | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| **Type** | None (NodePort) | NLB | NLB |
| **Listeners** | N/A | 80, 443, 6443 | 80, 443, 6443 |
| **Cross-Zone** | N/A | No | Yes |
| **Deletion Protection** | N/A | No | Yes |
| **Health Checks** | N/A | TCP/HTTP | TCP/HTTP |

### Database

| Attribute | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| **Mode** | Container (on K3s) | RDS single-AZ | RDS Multi-AZ |
| **Instance Class** | N/A | db.t3.micro | db.r6g.large |
| **Storage** | N/A | 20 GB gp3 | 100 GB gp3 (auto-scale to 500) |
| **Backup Retention** | N/A | 7 days | 30 days |
| **Deletion Protection** | N/A | No | Yes |
| **Performance Insights** | N/A | No | Yes |
| **Enhanced Monitoring** | N/A | No | 60s interval |
| **CloudWatch Logs** | N/A | No | postgresql, upgrade |

### Storage

| Attribute | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| **S3 Bucket** | ❌ | ✅ | ✅ |
| **S3 Versioning** | N/A | No | Yes |
| **S3 Encryption** | N/A | AES-256 | KMS |
| **S3 Lifecycle** | N/A | 30-day expiry | IA(30d) → Glacier(90d) → Expire(365d) |
| **EBS Volume Size** | 20 GB | 50 GB | 100 GB |
| **EBS Encryption** | Default | Default | KMS |

### Security & Secrets

| Attribute | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| **KMS Key** | ❌ | ❌ | ✅ (auto-rotating) |
| **Secrets Manager** | ❌ | ❌ | ✅ |
| **DB Credentials in SM** | ❌ | ❌ | ✅ |
| **OpenBao Unseal Keys in SM** | ❌ | ❌ | ✅ |
| **Security Groups** | 1 | 3 | 3 |

### IAM Policies

| Policy | ECONOMY | STANDARD | ENTERPRISE |
|--------|---------|----------|------------|
| **SSM Managed Instance** | ✅ | ✅ | ✅ |
| **CloudWatch ReadOnly** | ✅ | ✅ | ✅ |
| **CloudWatch Agent** | ❌ | ✅ | ✅ |
| **S3 Read/Write** | ❌ | ✅ | ✅ |
| **EBS CSI Driver** | ❌ | ✅ | ✅ |
| **KMS Encrypt/Decrypt** | ❌ | ❌ | ✅ |
| **Secrets Manager Read** | ❌ | ❌ | ✅ |

---

## Cost Estimates

| Resource | ECONOMY | STANDARD | ENTERPRISE |
|----------|---------|----------|------------|
| **EC2** | $8.50 | $90.00 | $420.00 |
| **EBS** | $1.60 | $12.00 | $48.00 |
| **NAT Gateway** | $0 | $0 | $96.00 |
| **Public IPs** | $0-3.60 | $0-10.80 | $0-21.60 |
| **RDS** | $0 | $15.00 | $60.00 |
| **NLB** | $0 | $16.00 | $16.00 |
| **S3** | $0 | $5.00 | $5.00 |
| **KMS** | $0 | $0 | $1.00 |
| **Secrets Manager** | $0 | $0 | $0.40 |
| **Total (approx)** | **~$10-14** | **~$140-150** | **~$650-670** |

> **Note:** These are rough estimates for planning purposes. Actual costs depend on usage, data transfer, and region. Use the `cost_guardrail_summary` output for a pre-apply review.

---

## What Does NOT Change Between Tiers

These elements are identical across all tiers:

- Same container images and versions
- Same K3s version and configuration
- Same Argo CD installation and GitOps workflow
- Same application code (cert-api, cert-worker, ca-service)
- Same SPIFFE ID scheme
- Same certificate profiles and enrollment protocols
- Same backup scripts (frequency varies)
- Same runbooks and operational procedures

---

## Tier Upgrade Path

```
ECONOMY ──► STANDARD ──► ENTERPRISE
   │            │            │
   ▼            ▼            ▼
 t3.micro    t3.medium    m6i.large
 1 node      3 nodes      6 nodes
 No LB       NLB          NLB (cross-zone)
 Container   RDS          RDS Multi-AZ
 No S3       S3           S3 + versioning
 No KMS      No KMS       KMS + SM
 Single AZ   Single AZ    Multi-AZ (3)
```

**Upgrade steps:**
1. Change `service_tier` in `terraform.tfvars`
2. Run `terraform plan` — review the cost guardrail summary
3. Run `terraform apply`
4. K3s cluster will be rebuilt with new topology (existing data in RDS/S3 is preserved)

> **Warning:** Upgrading from economy to standard/enterprise replaces the single EC2 instance with a multi-node cluster. The K3s cluster will be re-created. Back up any important data before upgrading.

---

## Economy Tier Guarantees

When `service_tier = "economy"`, the following resources are **never created**:

| Resource | Why Not | Monthly Cost Avoided |
|----------|---------|---------------------|
| NAT Gateway | No private subnets | ~$32/each |
| RDS | PostgreSQL runs in container | ~$15-60 |
| EKS | K3s used instead | ~$73 |
| Load Balancer | NodePort used instead | ~$16 |
| S3 Bucket | No backup storage | ~$5 |
| KMS Key | Default encryption | ~$1 |
| Secrets Manager | OpenBao standalone | ~$0.40 |

These are enforced by the tier-config module — there is no code path that creates these resources in economy mode.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | AWS Provider Engineer | Initial AWS tiers document |
