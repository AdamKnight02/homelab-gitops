# Provider Capability Matrix

## Overview

This document defines the formal capability mapping across cloud providers for the PKI platform. Provider-specific concepts remain below the platform abstraction layer.

---

## Core Infrastructure Capabilities

| Capability | Azure | AWS | Alibaba Cloud | Homelab |
|------------|-------|-----|---------------|---------|
| **Compute (VM)** | Azure VM | EC2 | ECS | libvirt/KVM |
| **Container Orchestration** | AKS (optional) | EKS (optional) | ACK (optional) | K3s |
| **Network** | VNet | VPC | VPC | libvirt NAT |
| **Subnet** | Subnet | Subnet | VSwitch | libvirt network |
| **Firewall** | NSG | Security Group | Security Group | iptables |
| **Load Balancer** | Azure LB / App GW | ELB (NLB/ALB) | SLB / NLB | K3s ServiceLB |
| **Public IP** | Public IP | Elastic IP | EIP | N/A |
| **DNS** | Azure DNS | Route 53 | Alibaba DNS | N/A |
| **NAT Gateway** | NAT Gateway | NAT Gateway | NAT Gateway | N/A |

---

## Storage Capabilities

| Capability | Azure | AWS | Alibaba Cloud | Homelab |
|------------|-------|-----|---------------|---------|
| **Object Storage** | Blob Storage | S3 | OSS | N/A |
| **Block Storage** | Managed Disk | EBS | Cloud Disk | local-path |
| **File Storage** | Azure Files | EFS | NAS | NFS |
| **Backup Service** | Azure Backup | AWS Backup | Hybrid Backup | N/A |

---

## Database Capabilities

| Capability | Azure | AWS | Alibaba Cloud | Homelab |
|------------|-------|-----|---------------|---------|
| **PostgreSQL (Managed)** | Azure Database for PostgreSQL Flexible | RDS PostgreSQL | ApsaraDB RDS PostgreSQL | Container |
| **PostgreSQL (Self-hosted)** | Container on VM | Container on EC2 | Container on ECS | Container |
| **HA PostgreSQL** | Zone-redundant | Multi-AZ | Multi-zone | N/A |

---

## Identity & Security Capabilities

| Capability | Azure | AWS | Alibaba Cloud | Homelab |
|------------|-------|-----|---------------|---------|
| **Identity** | Managed Identity | IAM Role / Instance Profile | RAM Role | N/A |
| **Secrets Store** | Key Vault | Secrets Manager | Secrets Manager | OpenBao |
| **Key Management** | Key Vault / Managed HSM | KMS / CloudHSM | KMS | OpenBao PKI |
| **Workload Identity** | SPIFFE/SPIRE | SPIFFE/SPIRE | SPIFFE/SPIRE | SPIFFE/SPIRE |

---

## Kubernetes Capabilities

| Capability | Azure | AWS | Alibaba Cloud | Homelab |
|------------|-------|-----|---------------|---------|
| **Managed K8s** | AKS | EKS | ACK | N/A |
| **Self-managed K8s** | K3s on VM | K3s on EC2 | K3s on ECS | K3s |
| **Storage Class** | managed-csi | gp2/gp3 (ebs.csi.aws.com) | alicloud-disk | local-path |
| **Ingress** | N/A (NodePort) | N/A (NodePort) | N/A (NodePort) | N/A (NodePort) |

---

## Monitoring Capabilities

| Capability | Azure | AWS | Alibaba Cloud | Homelab |
|------------|-------|-----|---------------|---------|
| **Metrics** | Azure Monitor | CloudWatch | CloudMonitor | Prometheus |
| **Dashboards** | Azure Dashboards | CloudWatch Dashboards | CloudMonitor Dashboards | Grafana |
| **Alerting** | Azure Alerts | CloudWatch Alarms | CloudMonitor Alarms | Alertmanager |
| **Platform Monitoring** | Prometheus/Grafana | Prometheus/Grafana | Prometheus/Grafana | Prometheus/Grafana |

---

## PKI-Specific Capabilities

| Capability | Azure | AWS | Alibaba Cloud | Homelab |
|------------|-------|-----|---------------|---------|
| **CA Platform** | EJBCA (container) | EJBCA (container) | EJBCA (container) | EJBCA (container) |
| **HSM Integration** | Azure Dedicated HSM | CloudHSM | Alibaba Cloud HSM | N/A |
| **Key Vault Integration** | Key Vault | KMS | KMS | OpenBao |
| **Certificate Manager** | N/A | ACM | SSL Certificates Service | cert-manager |

---

## External CA Integration Capabilities

| Capability | Azure | AWS | Alibaba Cloud | Homelab |
|------------|-------|-----|---------------|---------|
| **REST AnyCA Gateway** | Container on K3s | Container on K3s | Container on K3s | Container on K3s |
| **ACME Client** | Container | Container | Container | Container |
| **API Credentials Store** | Key Vault | Secrets Manager | Secrets Manager | OpenBao |

---

## Provider-Specific Cost Traps

| Trap | Azure | AWS | Alibaba Cloud |
|------|-------|-----|---------------|
| **Managed K8s** | AKS (~$70/mo cluster) | EKS (~$72/mo cluster) | ACK (~$60/mo cluster) |
| **NAT Gateway** | ~$32/mo + data | ~$32/mo + data | ~$30/mo + data |
| **Managed DB** | ~$25-200/mo | ~$15-200/mo | ~$15-200/mo |
| **Load Balancer** | ~$18/mo (LB) / ~$125/mo (App GW) | ~$16/mo (NLB) / ~$22/mo (ALB) | ~$15/mo (SLB) |
| **Public IP** | ~$3.60/mo | ~$3.60/mo (EIP) | ~$3/mo (EIP) |
| **HSM** | ~$1,000+/mo | ~$1,000+/mo | ~$800+/mo |

---

## Tier-to-Provider Mapping

### Economy Tier

| Resource | Azure | AWS | Alibaba Cloud |
|----------|-------|-----|---------------|
| Compute | Standard_B2s (2 vCPU, 4GB) | t3.small (2 vCPU, 2GB) | ecs.t6-c1m2.large (2 vCPU, 4GB) |
| Disk | StandardSSD_LRS 30GB | gp3 30GB | cloud_efficiency 30GB |
| Database | Container (PostgreSQL) | Container (PostgreSQL) | Container (PostgreSQL) |
| Object Storage | None (unless required) | None (unless required) | None (unless required) |
| Load Balancer | None | None | None |
| Managed K8s | No | No | No |
| NAT Gateway | No | No | No |
| Public IP | Optional (disabled default) | Optional (disabled default) | Optional (disabled default) |

### Standard Tier

| Resource | Azure | AWS | Alibaba Cloud |
|----------|-------|-----|---------------|
| Compute | Standard_D2s_v5 (2 vCPU, 8GB) ×2-3 | t3.medium (2 vCPU, 4GB) ×2-3 | ecs.g7.large (2 vCPU, 8GB) ×2-3 |
| Disk | Premium_LRS 50GB | gp3 50GB | cloud_essd 50GB |
| Database | Azure Database for PostgreSQL Flexible (Burstable) | RDS PostgreSQL (db.t3.micro) | ApsaraDB RDS PostgreSQL (basic) |
| Object Storage | Blob Storage (if needed) | S3 (if needed) | OSS (if needed) |
| Load Balancer | Azure LB (basic) | NLB | SLB |
| Managed K8s | No (K3s multi-node) | No (K3s multi-node) | No (K3s multi-node) |
| NAT Gateway | Optional | Optional | Optional |
| Public IP | 1 (for LB) | 1 (for LB) | 1 (for LB) |

### Enterprise Tier

| Resource | Azure | AWS | Alibaba Cloud |
|----------|-------|-----|---------------|
| Compute | Standard_D4s_v5 (4 vCPU, 16GB) ×3+ | m6i.large (2 vCPU, 8GB) ×3+ | ecs.g7.xlarge (4 vCPU, 16GB) ×3+ |
| Disk | Premium_LRS 100GB+ | gp3 100GB+ | cloud_essd 100GB+ |
| Database | Azure Database for PostgreSQL Flexible (HA) | RDS PostgreSQL (Multi-AZ) | ApsaraDB RDS PostgreSQL (HA) |
| Object Storage | Blob Storage (GRS) | S3 (versioned) | OSS (versioned) |
| Load Balancer | Azure LB / App GW | NLB / ALB | SLB / NLB |
| Managed K8s | Optional (AKS) | Optional (EKS) | Optional (ACK) |
| NAT Gateway | Yes (if private subnets) | Yes (if private subnets) | Yes (if private subnets) |
| Public IP | Multiple | Multiple | Multiple |
| HSM | Optional (Dedicated HSM) | Optional (CloudHSM) | Optional (Cloud HSM) |
| WAF | Optional (App GW WAF) | Optional (AWS WAF) | Optional (WAF) |

---

## Provider Authentication Status

| Provider | CLI Tool | Auth Status | Notes |
|----------|----------|-------------|-------|
| Azure | az 2.90.0 | ✅ Authenticated | User: aknight@keystonepartnerstestoutlook.onmicrosoft.com |
| AWS | aws 2.36.38 | ✅ Authenticated | Account: 962500057493, User: AdamKnight |
| Alibaba Cloud | aliyun | ❌ Not installed | No credentials configured |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | Master Orchestrator | Initial provider capability matrix |
