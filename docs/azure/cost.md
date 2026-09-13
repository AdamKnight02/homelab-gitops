# Cost Analysis — Azure Implementation

## Pay-As-You-Go Reality Check

**Your Azure subscription is PAY-AS-YOU-GO. No free credits. Every resource costs money.**

## Cost Estimation by Size Class

### Small Environment (Dev)

| Resource | SKU | Monthly Cost (USD) |
|----------|-----|-------------------|
| 1x VM (small) | Standard_B2s | ~$30 |
| 1x PostgreSQL (small) | B_Standard_B1ms | ~$25 |
| 1x Storage Account | Standard_LRS | ~$5 |
| 1x Key Vault | Standard | ~$1 |
| 1x Application Gateway | WAF_v2 (1 instance) | ~$150 |
| Log Analytics | 5 GB/month | ~$10 |
| **Total** | | **~$221/month** |

### Medium Environment (Staging)

| Resource | SKU | Monthly Cost (USD) |
|----------|-----|-------------------|
| 2x VM (medium) | Standard_D4s_v5 | ~$280 |
| 1x PostgreSQL (medium, HA) | GP_Standard_D2s_v3 | ~$180 |
| 1x Storage Account | Standard_ZRS | ~$15 |
| 1x Key Vault | Standard | ~$2 |
| 2x Application Gateway | WAF_v2 (2 instances) | ~$300 |
| 2x SCEP Container | ACI (2 vCPU, 4 GB) | ~$60 |
| Log Analytics | 20 GB/month | ~$40 |
| **Total** | | **~$877/month** |

### Large Environment (Production)

| Resource | SKU | Monthly Cost (USD) |
|----------|-----|-------------------|
| 3x VM (large) | Standard_D8s_v5 | ~$840 |
| 1x PostgreSQL (large, HA) | GP_Standard_D4s_v3 | ~$360 |
| 1x Storage Account | Standard_GRS | ~$50 |
| 1x Key Vault | Premium (HSM) | ~$150 |
| 3x Application Gateway | WAF_v2 (3 instances) | ~$450 |
| 4x SCEP Container | ACI (4 vCPU, 8 GB) | ~$240 |
| 2x ACME Container | ACI (2 vCPU, 4 GB) | ~$60 |
| 1x Automation Account | Basic | ~$10 |
| Log Analytics | 100 GB/month | ~$200 |
| Azure Monitor | 50 GB metrics | ~$100 |
| **Total** | | **~$2,460/month** |

## Cost Optimization Strategies

### 1. Right-Size from Start

```yaml
# DON'T over-provision
pki:
  count: 2
  size_class: large  # $840/month

# DO start small, scale up
pki:
  count: 1
  size_class: medium  # $140/month
```

### 2. Use Auto-Shutdown for Dev

```yaml
cost_optimization:
  auto_shutdown_dev: true  # Saves ~70% on dev VMs
```

### 3. Reserved Instances for Production

```yaml
cost_optimization:
  reserved_instances: true  # 1-year RI saves ~30%, 3-year saves ~50%
```

### 4. Spot Instances for Non-Critical

```yaml
cost_optimization:
  spot_instances: true  # Up to 90% savings, but can be evicted
```

### 5. Storage Lifecycle Management

```yaml
storage:
  containers:
    - name: logs
      retention_days: 30  # Auto-delete after 30 days
    - name: backups
      retention_days: 90  # Move to cool storage after 30 days
```

## High-Cost Components to Watch

| Component | Cost Driver | Optimization |
|-----------|-------------|--------------|
| Application Gateway | Per-instance + data processed | Use fewer instances, enable autoscaling |
| PostgreSQL HA | 2x compute cost | Use single instance for dev |
| Key Vault Premium | HSM operations | Use Standard for non-HSM keys |
| Log Analytics | Data ingestion | Filter logs, reduce retention |
| Public IPs | Static IPs charged | Use dynamic where possible |
| Data Transfer | Cross-region egress | Keep resources in same region |

## Cost Review Checklist

Before deploying:

- [ ] Reviewed size_class selections
- [ ] Confirmed count matches actual need
- [ ] Enabled auto-shutdown for dev
- [ ] Selected appropriate storage redundancy
- [ ] Reviewed log retention periods
- [ ] Checked for unused public IPs
- [ ] Verified no orphaned resources
- [ ] Compared RI vs PAYG for production

## Cost Monitoring

### Budget Alerts

```hcl
resource "azurerm_consumption_budget_resource_group" "customer" {
  name              = "budget-${var.customer_id}"
  resource_group_id = azurerm_resource_group.customer.id
  
  amount     = var.monthly_budget
  time_grain = "Monthly"
  
  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.budget_alert_email]
  }
  
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_emails = [var.budget_alert_email]
    contact_groups = [azurerm_monitor_action_group.critical.id]
  }
}
```

### Cost Allocation Tags

All resources tagged with:
- `customer`: Customer ID
- `environment`: dev/staging/prod
- `component`: pki/gateway/scep/acme
- `cost-center`: Billing code

## Sample Cost Report

```
CUSTOMER: contoso
ENVIRONMENT: prod
PROVIDER: azure
REGION: eastus2

ESTIMATED MONTHLY COST:

Compute:
  - 2x Standard_D4s_v5 (PKI VMs): $280
  - 2x Standard_B2s (Gateway VMs): $60
  - 4x ACI (SCEP): $120
  - 2x ACI (ACME): $60
  Subtotal: $520

Database:
  - PostgreSQL GP_Standard_D2s_v3 (HA): $180
  Subtotal: $180

Storage:
  - Standard_GRS (100 GB): $25
  - Backup storage (50 GB): $10
  Subtotal: $35

Networking:
  - Application Gateway WAF_v2 (2 instances): $300
  - Public IPs (3): $15
  - Data transfer (100 GB egress): $10
  Subtotal: $325

Security:
  - Key Vault Standard: $2
  - Key Vault operations: $5
  Subtotal: $7

Monitoring:
  - Log Analytics (20 GB): $40
  - Azure Monitor (10 GB metrics): $20
  Subtotal: $60

Automation:
  - Automation Account Basic: $10
  Subtotal: $10

TOTAL ESTIMATED: $1,137/month

HIGH-COST COMPONENTS:
1. Application Gateway ($300) - Consider reducing instances
2. Compute ($520) - Review VM sizes
3. Networking ($325) - Review data transfer patterns

RECOMMENDATIONS:
- Enable auto-shutdown for non-production hours (save ~$200/month)
- Use 1-year Reserved Instances for production VMs (save ~$150/month)
- Review log retention (reduce from 90 to 30 days, save ~$20/month)
- Consider smaller Application Gateway SKU for dev/staging
```

## Cost Governance

### Approval Gates

| Monthly Cost | Approval Required |
|--------------|-------------------|
| < $500 | Platform team lead |
| $500 - $2,000 | Platform team + Finance |
| > $2,000 | Platform team + Finance + Customer |

### Cost Review Cadence

- **Weekly**: Review actual vs estimated costs
- **Monthly**: Optimize underutilized resources
- **Quarterly**: Review RI/Spot strategy
- **Annually**: Renegotiate EA/MCA pricing

## Emergency Cost Controls

If costs exceed budget by >20%:

1. **Immediate**: Alert platform team
2. **Short-term**: Review and right-size resources
3. **Long-term**: Implement additional cost controls

**Auto-remediation** (if enabled):
- Shutdown dev VMs outside business hours
- Scale down non-critical environments
- Alert on orphaned resources
