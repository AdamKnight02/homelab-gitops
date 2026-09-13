# Alibaba Cloud Tier Configuration

## Overview

This document describes how the platform's service tiers (ECONOMY, STANDARD, ENTERPRISE) map to Alibaba Cloud resources. The tier configuration is centralized in `infra/terraform/modules/alibaba/tier-config/main.tf`.

**Core Principle:** Tiers are intent declarations, not cloud SKUs. A customer says `service_tier: standard`, and the tier-config module translates that into Alibaba Cloud-specific resource decisions.

---

## Tier-to-Resource Mapping

### Compute (ECS)

| Attribute | ECONOMY | STANDARD | ENTERPRISE |
|-----------|---------|----------|------------|
| **Instance Count** | 1 | 3 | 6 |
| **Instance Type** | `ecs.t6-c1m2.large` | `ecs.t6-c1m4.large` | `ecs.g6.xlarge` |
| **vCPUs** | 2 | 2 | 4 |
| **Memory** | 2 GiB | 4 GiB | 16 GiB |
| **Disk Category** | `cloud_efficiency` | `cloud_ssd` | `cloud_essd` |
| **Disk Size** | 30 GB | 50 GB | 100 GB |
| **Public IP** | Optional | Optional | Optional |
| **Bandwidth** | 0 Mbps (no public IP) | 0-5 Mbps | 0-10 Mbps |

**Instance Type Override:** Use `alibaba_instance_type_override` to override the tier default.

### Networking

| Feature | ECONOMY | STANDARD | ENTERPRISE |
|---------|---------|----------|------------|
| **Multi-Zone** | No | No | Yes (3 zones) |
| **NAT Gateway** | No | No | Yes |
| **EIP** | No | No | Yes |
| **Private Subnets** | No | No | Yes |

### Load Balancer

| Feature | ECONOMY | STANDARD | ENTERPRISE |
|---------|---------|----------|------------|
| **Type** | None (NodePort) | NLB | NLB |
| **Address Type** | N/A | Intranet | Internet |
| **Health Checks** | N/A | TCP:6443 | TCP:6443 |

### Database (ApsaraDB RDS)

| Feature | ECONOMY | STANDARD | ENTERPRISE |
|---------|---------|----------|------------|
| **Mode** | Container | RDS single-zone | RDS multi-zone HA |
| **Instance Type** | N/A | `pg.n2.medium.2c` | `pg.n4.large.2c` |
| **Storage** | N/A | 20 GB | 20 GB |
| **HA** | N/A | No | Yes (multi-zone) |

### Storage (OSS)

| Feature | ECONOMY | STANDARD | ENTERPRISE |
|---------|---------|----------|------------|
| **Enabled** | No | Yes | Yes |
| **Versioning** | N/A | No | Yes |
| **Encryption** | N/A | AES256 | AES256 |

### Secrets & KMS

| Feature | ECONOMY | STANDARD | ENTERPRISE |
|---------|---------|----------|------------|
| **KMS Key** | No | No | Yes |
| **Secrets Manager** | No | No | Yes |

### Monitoring

| Feature | ECONOMY | STANDARD | ENTERPRISE |
|---------|---------|----------|------------|
| **CloudMonitor** | No | Yes | Yes |
| **Prometheus** | No | Yes | Yes |
| **Grafana** | No | Yes | Yes |

### ACK (Kubernetes)

| Feature | ECONOMY | STANDARD | ENTERPRISE |
|---------|---------|----------|------------|
| **ACK Enabled** | No | No | Opt-in via `enable_ack` |
| **Default** | K3s | K3s | K3s |

---

## Cost Guardrails

### Resource Count Report

Before any `terraform apply`, review the `cost_report` output:

| Resource | ECONOMY | STANDARD | ENTERPRISE |
|----------|---------|----------|------------|
| ECS Instances | 1 | 3 | 6 |
| Disks | 1 (30 GB) | 3 (150 GB) | 6 (600 GB) |
| NAT Gateways | 0 | 0 | 1 |
| EIP Addresses | 0 | 0 | 1 |
| Public IPs | 0-1 | 0-3 | 0-6 |
| RDS Instances | 0 | 1 | 1 |
| RDS Multi-Zone | No | No | Yes |
| ACK Clusters | 0 | 0 | 0-1 |
| Load Balancers | 0 | 1 | 1 |
| OSS Buckets | 0 | 1 | 1 |
| KMS Keys | 0 | 0 | 1 |
| Secrets Manager | 0 | 0 | 1 |

### Estimated Monthly Cost

| Tier | Estimated Cost | Key Cost Drivers |
|------|---------------|------------------|
| **ECONOMY** | ~$13.50 | 1 ECS instance, 1 disk |
| **STANDARD** | ~$135 | 3 ECS instances, RDS, NLB, OSS |
| **ENTERPRISE** | ~$600 | 6 ECS instances, RDS HA, NLB, NAT, EIP, OSS, KMS |

> **Note:** These are rough estimates. Actual costs vary by region, usage patterns, and data transfer. Always review the `cost_guardrail_summary` output before applying.

### Economy Tier Safeguards

The following resources are **never** created in Economy tier:

- ❌ NAT Gateway
- ❌ EIP
- ❌ RDS (ApsaraDB)
- ❌ Load Balancer (SLB/NLB)
- ❌ OSS Bucket
- ❌ KMS Key
- ❌ Secrets Manager
- ❌ ACK Cluster
- ❌ Multi-zone deployment

If any of these appear in a plan for Economy tier, **stop and investigate**.

---

## Tier Selection Guide

### Choose ECONOMY when:
- Development or testing on Alibaba Cloud
- Proof-of-concept or evaluation
- Budget is the primary constraint
- Single-node K3s is sufficient
- No managed database needed

### Choose STANDARD when:
- Production workloads on Alibaba Cloud
- High availability required (3-node K3s)
- Managed database (RDS) needed
- Internal load balancing required
- Object storage (OSS) for backups

### Choose ENTERPRISE when:
- Mission-critical PKI on Alibaba Cloud
- Multi-zone deployment required
- Maximum availability (99.95%+)
- Full HA for all components
- KMS encryption and secrets management
- Compliance requirements (audit logging, encryption)

---

## Usage

### Setting the Tier

```hcl
# In your terraform.tfvars or root module
service_tier = "standard"
```

### Overriding Instance Type

```hcl
service_tier                   = "standard"
alibaba_instance_type_override = "ecs.g6.large"
```

### Enabling ACK (Enterprise Only)

```hcl
service_tier = "enterprise"
enable_ack   = true
```

### Reviewing Cost Guardrails

```bash
terraform plan -target=module.tier_config
terraform output cost_guardrail_summary
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Agent 6 (Alibaba Engineer) | Initial tier configuration |
