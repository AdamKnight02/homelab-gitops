# Customer Intent Schema v2

## Overview

This document defines the **provider-neutral customer intent schema** (schema_version: 2). Customer intent describes WHAT the customer needs, not HOW to build it. Provider-specific implementation details are resolved by the platform's translation engine.

**Core Principle:** Customer configs contain `service_tier: standard`, never `azure_vm_size: D4sv5` or `aws_instance_type: m6i.large`.

---

## Schema Definition

```yaml
# =============================================================================
# Customer Intent Schema v2
# =============================================================================
# Provider-neutral customer configuration.
# All provider-specific values are resolved by the platform translation engine.
# =============================================================================

schema_version: 2

# ---------------------------------------------------------------------------
# Customer Identity
# ---------------------------------------------------------------------------
customer:
  id: contoso                    # Unique customer identifier (lowercase, no spaces)
  name: "Contoso Ltd"            # Display name
  environment: production        # lab, dev, staging, production

# ---------------------------------------------------------------------------
# Cloud Provider
# ---------------------------------------------------------------------------
cloud:
  provider: azure                # azure, aws, alibaba
  region_class: primary          # primary, secondary, dr
  # region is resolved by the platform based on provider + region_class

# ---------------------------------------------------------------------------
# Service Tier
# ---------------------------------------------------------------------------
# Tiers are INTENT, not cloud SKUs.
# The platform translates tier into provider-specific infrastructure.
service_tier: standard           # economy, standard, enterprise

# ---------------------------------------------------------------------------
# Availability
# ---------------------------------------------------------------------------
availability:
  level: regional                # single_zone, regional, multi_regional
  # regional = multi-AZ within one region
  # multi_regional = active-active across regions (enterprise only)

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
network:
  cidr: "10.50.0.0/16"           # VPC/VNet CIDR
  exposure: private_preferred    # public, private_preferred, private
  # private_preferred = private endpoints where possible, public where required
  # private = fully private (requires VPN/DirectConnect/ExpressRoute)

# ---------------------------------------------------------------------------
# Gateway / Bastion
# ---------------------------------------------------------------------------
gateway:
  enabled: true                  # Deploy gateway/bastion for secure access
  type: bastion                  # bastion, vpn, direct_connect

# ---------------------------------------------------------------------------
# PKI Platform
# ---------------------------------------------------------------------------
pki:
  replicas: auto                 # auto = tier-based default
  # economy: 1, standard: 2, enterprise: 3+

# ---------------------------------------------------------------------------
# SCEP Protocol
# ---------------------------------------------------------------------------
scep:
  enabled: true
  replicas: auto                 # auto = tier-based default

# ---------------------------------------------------------------------------
# ACME Protocol
# ---------------------------------------------------------------------------
acme:
  enabled: true
  replicas: auto                 # auto = tier-based default

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
database:
  engine: postgresql             # postgresql (only supported engine)
  profile: managed               # self_hosted, managed, managed_ha
  # self_hosted = container on K3s (economy)
  # managed = cloud-managed PostgreSQL (standard)
  # managed_ha = HA cloud-managed PostgreSQL (enterprise)

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------
storage:
  profile: standard              # basic, standard, premium
  # basic = local-path / standard disks (economy)
  # standard = cloud CSI / premium disks (standard)
  # premium = cloud CSI / premium disks + backup (enterprise)

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------
monitoring:
  enabled: true
  retention_profile: standard    # basic, standard, extended
  # basic = 7 days (economy)
  # standard = 30 days (standard)
  # extended = 90 days (enterprise)

# ---------------------------------------------------------------------------
# External CA Integration
# ---------------------------------------------------------------------------
# Supports multiple external CAs (future).
# First pipeline UI may expose single provider.
external_cas:
  - name: primary-public-ca      # Unique identifier for this integration
    provider: digicert           # none, letsencrypt, digicert, sectigo, globalsign, entrust, godaddy, custom
    enabled: true
    integration_type: anyca      # anyca, acme, native_api, custom
    deployment_profile: standard # economy, standard, enterprise

  # Example: Add a second CA
  # - name: public-acme
  #   provider: letsencrypt
  #   enabled: true
  #   integration_type: acme
  #   deployment_profile: economy

# ---------------------------------------------------------------------------
# Features
# ---------------------------------------------------------------------------
features:
  spire: true                    # SPIFFE/SPIRE workload identity
  openbao: true                  # OpenBao secrets management
  rabbitmq: true                 # RabbitMQ message queue
  inventory: true                # Certificate inventory
  audit: true                    # Audit logging
  cert_manager: true             # cert-manager for K8s certs

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------
backup:
  enabled: true
  profile: standard              # basic, standard, extended
  # basic = daily snapshots, 7-day retention (economy)
  # standard = daily snapshots, 30-day retention (standard)
  # extended = daily snapshots, 90-day retention + cross-region (enterprise)

# ---------------------------------------------------------------------------
# Cost Control
# ---------------------------------------------------------------------------
cost_control:
  max_monthly_cost_usd: 500      # Hard stop if estimate exceeds this
  require_approval_above_usd: 200 # Require approval if estimate exceeds this
  allowed_services:              # Explicitly allowed services
    - compute
    - database
    - storage
    - load_balancer
  blocked_services:              # Explicitly blocked services
    - nat_gateway                # Blocked in economy
    - managed_kubernetes         # Blocked unless explicitly enabled

# ---------------------------------------------------------------------------
# Tags / Labels
# ---------------------------------------------------------------------------
tags:
  project: pki-platform
  cost_center: it-security
  owner: security-team
  compliance: none               # none, pci, hipaa, soc2
```

---

## Tier Resolution

The platform translates `service_tier` into provider-specific infrastructure using tier maps.

### Economy Tier Resolution

| Intent | Azure | AWS | Alibaba |
|--------|-------|-----|---------|
| Compute | Standard_B2s | t3.small | ecs.t6-c1m2.large |
| Disk | StandardSSD_LRS 30GB | gp3 30GB | cloud_efficiency 30GB |
| Database | Container (PostgreSQL) | Container (PostgreSQL) | Container (PostgreSQL) |
| Load Balancer | None | None | None |
| Managed K8s | No | No | No |
| NAT Gateway | No | No | No |
| Public IP | Optional (disabled) | Optional (disabled) | Optional (disabled) |
| Replicas | 1 | 1 | 1 |

### Standard Tier Resolution

| Intent | Azure | AWS | Alibaba |
|--------|-------|-----|---------|
| Compute | Standard_D2s_v5 ×2-3 | t3.medium ×2-3 | ecs.g7.large ×2-3 |
| Disk | Premium_LRS 50GB | gp3 50GB | cloud_essd 50GB |
| Database | Azure Database for PostgreSQL Flexible | RDS PostgreSQL (db.t3.micro) | ApsaraDB RDS PostgreSQL (basic) |
| Load Balancer | Azure LB | NLB | SLB |
| Managed K8s | No (K3s multi-node) | No (K3s multi-node) | No (K3s multi-node) |
| NAT Gateway | Optional | Optional | Optional |
| Public IP | 1 (for LB) | 1 (for LB) | 1 (for LB) |
| Replicas | 2 | 2 | 2 |

### Enterprise Tier Resolution

| Intent | Azure | AWS | Alibaba |
|--------|-------|-----|---------|
| Compute | Standard_D4s_v5 ×3+ | m6i.large ×3+ | ecs.g7.xlarge ×3+ |
| Disk | Premium_LRS 100GB+ | gp3 100GB+ | cloud_essd 100GB+ |
| Database | Azure Database for PostgreSQL Flexible (HA) | RDS PostgreSQL (Multi-AZ) | ApsaraDB RDS PostgreSQL (HA) |
| Load Balancer | Azure LB / App GW | NLB / ALB | SLB / NLB |
| Managed K8s | Optional (AKS) | Optional (EKS) | Optional (ACK) |
| NAT Gateway | Yes (if private subnets) | Yes (if private subnets) | Yes (if private subnets) |
| Public IP | Multiple | Multiple | Multiple |
| Replicas | 3+ | 3+ | 3+ |

---

## Validation Rules

### Schema Validation

```yaml
# Required fields
required:
  - schema_version
  - customer.id
  - customer.environment
  - cloud.provider
  - service_tier

# Enum validation
enums:
  schema_version: [2]
  customer.environment: [lab, dev, staging, production]
  cloud.provider: [azure, aws, alibaba]
  cloud.region_class: [primary, secondary, dr]
  service_tier: [economy, standard, enterprise]
  availability.level: [single_zone, regional, multi_regional]
  network.exposure: [public, private_preferred, private]
  gateway.type: [bastion, vpn, direct_connect]
  database.engine: [postgresql]
  database.profile: [self_hosted, managed, managed_ha]
  storage.profile: [basic, standard, premium]
  monitoring.retention_profile: [basic, standard, extended]
  backup.profile: [basic, standard, extended]
  external_cas[].provider: [none, letsencrypt, digicert, sectigo, globalsign, entrust, godaddy, custom]
  external_cas[].integration_type: [anyca, acme, native_api, custom]
  external_cas[].deployment_profile: [economy, standard, enterprise]

# Conditional validation
conditional:
  # Enterprise tier requires multi-zone or multi-regional availability
  - if: service_tier == "enterprise"
    then: availability.level in ["regional", "multi_regional"]

  # Economy tier cannot use managed_ha database
  - if: service_tier == "economy"
    then: database.profile != "managed_ha"

  # Economy tier cannot use premium storage
  - if: service_tier == "economy"
    then: storage.profile != "premium"

  # Multi-regional availability requires enterprise tier
  - if: availability.level == "multi_regional"
    then: service_tier == "enterprise"
```

---

## Migration from v1

### v1 Schema (Legacy)

```yaml
# v1 was provider-specific
azure_vm_size: Standard_B2s
aws_instance_type: t3.micro
```

### v2 Schema (Current)

```yaml
# v2 is provider-neutral
service_tier: economy
```

### Migration Path

1. **Identify tier** from existing v1 config
2. **Map to v2** using tier definitions
3. **Remove provider-specific** values
4. **Add new v2 fields** with defaults
5. **Validate** against v2 schema

---

## Examples

### Economy Tier (Azure)

```yaml
schema_version: 2
customer:
  id: contoso
  environment: dev
cloud:
  provider: azure
  region_class: primary
service_tier: economy
availability:
  level: single_zone
network:
  cidr: "10.50.0.0/16"
  exposure: private_preferred
gateway:
  enabled: false
pki:
  replicas: auto
scep:
  enabled: false
acme:
  enabled: false
database:
  engine: postgresql
  profile: self_hosted
storage:
  profile: basic
monitoring:
  enabled: true
  retention_profile: basic
external_cas: []
features:
  spire: true
  openbao: true
  rabbitmq: true
  inventory: true
  audit: true
  cert_manager: true
backup:
  enabled: false
cost_control:
  max_monthly_cost_usd: 50
tags:
  project: pki-platform
  cost_center: it-security
```

### Standard Tier (AWS)

```yaml
schema_version: 2
customer:
  id: contoso
  environment: production
cloud:
  provider: aws
  region_class: primary
service_tier: standard
availability:
  level: regional
network:
  cidr: "10.50.0.0/16"
  exposure: private_preferred
gateway:
  enabled: true
  type: bastion
pki:
  replicas: auto
scep:
  enabled: true
  replicas: auto
acme:
  enabled: true
  replicas: auto
database:
  engine: postgresql
  profile: managed
storage:
  profile: standard
monitoring:
  enabled: true
  retention_profile: standard
external_cas:
  - name: primary-public-ca
    provider: digicert
    enabled: true
    integration_type: anyca
    deployment_profile: standard
features:
  spire: true
  openbao: true
  rabbitmq: true
  inventory: true
  audit: true
  cert_manager: true
backup:
  enabled: true
  profile: standard
cost_control:
  max_monthly_cost_usd: 500
  require_approval_above_usd: 200
tags:
  project: pki-platform
  cost_center: it-security
  compliance: none
```

### Enterprise Tier (Alibaba)

```yaml
schema_version: 2
customer:
  id: contoso
  environment: production
cloud:
  provider: alibaba
  region_class: primary
service_tier: enterprise
availability:
  level: regional
network:
  cidr: "10.50.0.0/16"
  exposure: private
gateway:
  enabled: true
  type: vpn
pki:
  replicas: auto
scep:
  enabled: true
  replicas: auto
acme:
  enabled: true
  replicas: auto
database:
  engine: postgresql
  profile: managed_ha
storage:
  profile: premium
monitoring:
  enabled: true
  retention_profile: extended
external_cas:
  - name: primary-public-ca
    provider: digicert
    enabled: true
    integration_type: anyca
    deployment_profile: enterprise
  - name: public-acme
    provider: letsencrypt
    enabled: true
    integration_type: acme
    deployment_profile: standard
features:
  spire: true
  openbao: true
  rabbitmq: true
  inventory: true
  audit: true
  cert_manager: true
backup:
  enabled: true
  profile: extended
cost_control:
  max_monthly_cost_usd: 2000
  require_approval_above_usd: 1000
tags:
  project: pki-platform
  cost_center: it-security
  compliance: soc2
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0 | 2026-09-12 | Master Orchestrator | Initial customer intent schema v2 |
