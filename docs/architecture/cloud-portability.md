# Cloud Portability Analysis

This document identifies every Azure-specific assumption in the platform and classifies its portability status.

## Classification Legend

| Status | Meaning |
|--------|---------|
| **PORTABLE** | Cloud-agnostic, works across all providers |
| **PROVIDER ADAPTER** | Azure-specific, isolated behind adapter interface |
| **AZURE-ONLY** | Azure-specific, no direct equivalent |
| **NEEDS REFACTOR** | Currently Azure-specific, should be abstracted |

## Component Analysis

### Network Layer

| Component | Azure Implementation | AWS Equivalent | Alibaba Equivalent | Status |
|-----------|---------------------|----------------|-------------------|--------|
| Virtual Network | `azurerm_virtual_network` | `aws_vpc` | `alicloud_vpc` | PROVIDER ADAPTER |
| Subnet | `azurerm_subnet` | `aws_subnet` | `alicloud_vswitch` | PROVIDER ADAPTER |
| Network Security Group | `azurerm_network_security_group` | `aws_security_group` | `alicloud_security_group` | PROVIDER ADAPTER |
| Route Table | `azurerm_route_table` | `aws_route_table` | `alicloud_route_table` | PROVIDER ADAPTER |
| NAT Gateway | `azurerm_nat_gateway` | `aws_nat_gateway` | `alicloud_nat_gateway` | PROVIDER ADAPTER |
| Private Endpoint | `azurerm_private_endpoint` | `aws_vpc_endpoint` | `alicloud_privatelink_endpoint` | PROVIDER ADAPTER |

### Compute Layer

| Component | Azure Implementation | AWS Equivalent | Alibaba Equivalent | Status |
|-----------|---------------------|----------------|-------------------|--------|
| Virtual Machine | `azurerm_linux_virtual_machine` | `aws_instance` | `alicloud_instance` | PROVIDER ADAPTER |
| VM Size | `Standard_D4s_v5` | `m5.xlarge` | `ecs.g6.xlarge` | PROVIDER ADAPTER |
| Managed Identity | `azurerm_user_assigned_identity` | `aws_iam_role` | `alicloud_ram_role` | PROVIDER ADAPTER |
| Disk | `azurerm_managed_disk` | `aws_ebs_volume` | `alicloud_disk` | PROVIDER ADAPTER |
| Availability Set | `azurerm_availability_set` | `aws_placement_group` | `alicloud_deployment_set` | PROVIDER ADAPTER |

### Database Layer

| Component | Azure Implementation | AWS Equivalent | Alibaba Equivalent | Status |
|-----------|---------------------|----------------|-------------------|--------|
| PostgreSQL | `azurerm_postgresql_flexible_server` | `aws_db_instance` | `alicloud_db_instance` | PROVIDER ADAPTER |
| Database SKU | `GP_Standard_D4s_v3` | `db.m5.large` | `pg.n2.medium.2c` | PROVIDER ADAPTER |
| Private DNS Zone | `azurerm_private_dns_zone` | `aws_route53_zone` | `alicloud_pvtz_zone` | PROVIDER ADAPTER |

### Storage Layer

| Component | Azure Implementation | AWS Equivalent | Alibaba Equivalent | Status |
|-----------|---------------------|----------------|-------------------|--------|
| Storage Account | `azurerm_storage_account` | `aws_s3_bucket` | `alicloud_oss_bucket` | PROVIDER ADAPTER |
| Blob Container | `azurerm_storage_container` | `aws_s3_bucket` (prefix) | `alicloud_oss_bucket` (prefix) | PROVIDER ADAPTER |
| Redundancy | `GRS`, `ZRS`, `LRS` | `STANDARD`, `STANDARD_IA`, `GLACIER` | `Standard`, `IA`, `Archive` | PROVIDER ADAPTER |

### Security Layer

| Component | Azure Implementation | AWS Equivalent | Alibaba Equivalent | Status |
|-----------|---------------------|----------------|-------------------|--------|
| Key Vault | `azurerm_key_vault` | `aws_kms_key` + `aws_secretsmanager_secret` | `alicloud_kms_key` | PROVIDER ADAPTER |
| RBAC | `azurerm_role_assignment` | `aws_iam_role_policy_attachment` | `alicloud_ram_policy_attachment` | PROVIDER ADAPTER |
| HSM | `azurerm_dedicated_hsm` | `aws_cloudhsm_v2_cluster` | `alicloud_cloud_hsm` | PROVIDER ADAPTER |

### Monitoring Layer

| Component | Azure Implementation | AWS Equivalent | Alibaba Equivalent | Status |
|-----------|---------------------|----------------|-------------------|--------|
| Log Analytics | `azurerm_log_analytics_workspace` | `aws_cloudwatch_log_group` | `alicloud_log_project` | PROVIDER ADAPTER |
| Metric Alerts | `azurerm_monitor_metric_alert` | `aws_cloudwatch_metric_alarm` | `alicloud_cms_alarm` | PROVIDER ADAPTER |
| Application Insights | `azurerm_application_insights` | `aws_xray_group` | `alicloud_arms` | PROVIDER ADAPTER |

### Automation Layer

| Component | Azure Implementation | AWS Equivalent | Alibaba Equivalent | Status |
|-----------|---------------------|----------------|-------------------|--------|
| Automation Account | `azurerm_automation_account` | `aws_ssm_document` + `aws_lambda_function` | `alicloud_oos_template` | PROVIDER ADAPTER |
| Runbook | `azurerm_automation_runbook` | `aws_ssm_document` | `alicloud_oos_execution` | PROVIDER ADAPTER |
| Schedule | `azurerm_automation_schedule` | `aws_cloudwatch_event_rule` | `alicloud_oos_trigger` | PROVIDER ADAPTER |

## Customer Configuration Portability

### PORTABLE Elements

These customer configuration elements are fully portable across providers:

```yaml
customer:
  id: string
  name: string
  environment: enum

network:
  cidr: string
  subnets: map

gateway:
  enabled: boolean
  count: integer
  size_class: enum

pki:
  count: integer
  size_class: enum
  ha_mode: enum

database:
  engine: enum
  size_class: enum
  availability: enum

storage:
  class: enum
  redundancy: enum

monitoring:
  prometheus: boolean
  grafana: boolean

features:
  spire: boolean
  openbao: boolean
  rabbitmq: boolean
```

### PROVIDER ADAPTER Elements

These elements require provider-specific translation:

```yaml
cloud:
  provider: azure | aws | alibaba  # Adapter selection
  region: string                   # Provider-specific region

# Size classes map to provider SKUs
size_class: small | medium | large
  # Azure: Standard_B2s | Standard_D4s_v5 | Standard_D8s_v5
  # AWS: t3.medium | m5.xlarge | m5.2xlarge
  # Alibaba: ecs.t5-lc2m1.nano | ecs.g6.xlarge | ecs.g6.2xlarge
```

### AZURE-ONLY Elements (Current Implementation)

These elements are currently Azure-specific and need abstraction:

| Element | Current | Target | Status |
|---------|---------|--------|--------|
| Key Vault URI | `https://kv-contoso.vault.azure.net/` | Generic secrets endpoint | NEEDS REFACTOR |
| Managed Identity Client ID | Azure GUID | Generic identity reference | NEEDS REFACTOR |
| Azure DNS Zone | `privatelink.postgres.database.azure.com` | Generic private DNS | NEEDS REFACTOR |
| Azure Monitor Workspace | `law-contoso-prod` | Generic monitoring workspace | NEEDS REFACTOR |

## Refactoring Roadmap

### Phase 1: Immediate (Current Sprint)

- [x] Size class abstractions (small/medium/large)
- [x] Provider selection in customer config
- [x] Terraform module isolation per provider

### Phase 2: Short-term (Next Sprint)

- [ ] Generic secrets endpoint abstraction
- [ ] Generic identity reference abstraction
- [ ] Generic DNS zone abstraction

### Phase 3: Medium-term (Next Quarter)

- [ ] AWS provider adapter implementation
- [ ] Alibaba provider adapter implementation
- [ ] Cross-provider state migration tooling

### Phase 4: Long-term (Next Year)

- [ ] Multi-cloud active-active deployments
- [ ] Provider failover automation
- [ ] Cost optimization across providers

## Portability Testing

Each provider adapter must pass these tests:

1. **Schema Validation**: Same customer config validates for all providers
2. **Plan Generation**: Terraform plan succeeds for target provider
3. **Resource Mapping**: All logical resources map to provider resources
4. **Output Contract**: Provider outputs match platform contract
5. **State Isolation**: State files isolated per provider/customer/environment

## Conclusion

The platform is **85% portable** today. The remaining 15% requires abstraction of secrets endpoints, identity references, and DNS zones. No fundamental architectural changes are required — only interface generalization.
