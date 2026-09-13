# Security Architecture — PKI Customer Environment Factory

## Identity Model

### 1. Pipeline Identity (CI/CD)

**GitHub Actions OIDC → Azure**

```yaml
# .github/workflows/deploy-customer.yml
permissions:
  id-token: write
  contents: read

- uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**Principle**: No long-lived secrets in GitHub. OIDC token exchange for short-lived Azure tokens.

**Permissions**:
- `Contributor` on customer resource groups only
- `Key Vault Secrets Officer` on customer Key Vaults
- No subscription-level access

### 2. Terraform Identity

**Service Principal per Customer**

```hcl
# Azure AD Application + Service Principal per customer
resource "azuread_application" "customer" {
  display_name = "sp-terraform-${var.customer_id}-${var.environment}"
}

resource "azuread_service_principal" "customer" {
  application_id = azuread_application.customer.application_id
}

resource "azurerm_role_assignment" "customer" {
  scope                = azurerm_resource_group.customer.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.customer.object_id
}
```

**Principle**: Least privilege per customer. No cross-customer access.

### 3. VM Identity

**Managed Identity per VM**

```hcl
resource "azurerm_user_assigned_identity" "vm" {
  name                = "id-${var.customer_id}-${var.component}"
  resource_group_name = azurerm_resource_group.customer.name
  location            = azurerm_resource_group.customer.location
}

resource "azurerm_role_assignment" "vm_keyvault" {
  scope                = azurerm_key_vault.customer.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.vm.principal_id
}
```

**Principle**: VMs authenticate to Azure services without stored credentials.

### 4. Workload Identity (Kubernetes)

**SPIFFE/SPIRE for Pod Identity**

```yaml
# SPIRE Server ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-server
  namespace: spire
data:
  server.conf: |
    server {
      bind_address = "0.0.0.0"
      bind_port = "8081"
      trust_domain = "pki.contoso.com"
      data_dir = "/run/spire/data"
      log_level = "INFO"
    }
    
    plugins {
      NodeAttestor "k8s_psat" {
        plugin_data {
          clusters = {
            "production" = {
              service_account_whitelist = ["spire:spire-agent"]
            }
          }
        }
      }
      
      KeyManager "disk" {
        plugin_data {
          keys_path = "/run/spire/data/keys.json"
        }
      }
      
      UpstreamAuthority "disk" {
        plugin_data {
          cert_file_path = "/run/spire/data/upstream-ca.crt"
          key_file_path = "/run/spire/data/upstream-ca.key"
        }
      }
    }
```

**Principle**: Workloads receive SPIFFE IDs for mTLS, not shared secrets.

### 5. PKI Signing Identity

**HSM-Backed CA Keys**

| CA Level | Key Storage | Access | Rotation |
|----------|-------------|--------|----------|
| Root CA | Offline HSM (air-gapped) | 2-of-3 Shamir | 25 years |
| Issuing CA | Azure Dedicated HSM / CloudHSM | HSM-controlled | 10 years |
| OCSP Signing | Azure Key Vault HSM | Key Vault RBAC | 2 years |
| SCEP/ACME | Azure Key Vault | Key Vault RBAC | 1 year |

**Principle**: CA private keys never leave HSM. Signing operations via HSM API only.

## Network Security

### Segmentation

```
Internet
    |
    v
[Gateway Subnet] ← Public IP, WAF, TLS termination
    |
    v
[Enrollment Subnet] ← SCEP, ACME services (private)
    |
    v
[PKI Subnet] ← EJBCA, OCSP, CRL (private, no internet)
    |
    v
[Management Subnet] ← Admin access only (Bastion)
```

### NSG Rules

| Subnet | Inbound | Outbound |
|--------|---------|----------|
| Gateway | 443 from Internet | 8080 to Enrollment, 8443 to PKI |
| Enrollment | 8080 from Gateway | 8080 to PKI, 443 to Internet (ACME) |
| PKI | 8443 from Gateway, 8080 from Enrollment | 5432 to Database, 8200 to OpenBao |
| Management | 22 from Bastion | All to PKI, Enrollment |

### Private Endpoints

All PaaS services use private endpoints:
- PostgreSQL: `privatelink.postgres.database.azure.com`
- Key Vault: `privatelink.vaultcore.azure.net`
- Storage: `privatelink.blob.core.windows.net`

## Secrets Management

### Layered Secrets

| Layer | Technology | Contents | Access |
|-------|-----------|----------|--------|
| Azure Key Vault | `azurerm_key_vault` | Terraform secrets, VM credentials | Managed Identity |
| OpenBao | `openbao` | Application secrets, short-lived certs | SPIFFE ID |
| EJBCA Crypto Token | HSM | CA signing keys | HSM API only |

### Secret Flow

```
Terraform (Azure Key Vault)
    |
    v
VM Configuration (Managed Identity → Key Vault)
    |
    v
Kubernetes (External Secrets Operator → OpenBao)
    |
    v
Applications (SPIFFE ID → OpenBao)
```

## PKI Safety Controls

### Never-Auto-Destroy

These resources are protected from accidental deletion:

```hcl
# Terraform lifecycle rules
resource "azurerm_key_vault" "customer" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server" "customer" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}
```

### High-Risk Operations

| Operation | Approval | Audit |
|-----------|----------|-------|
| Delete Root CA | Security team + Customer | Mandatory |
| Delete Issuing CA | Security team | Mandatory |
| Rotate CA keys | Security team | Mandatory |
| Revoke all certificates | Security team + Customer | Mandatory |
| Change trust roots | Security team | Mandatory |
| Modify certificate profiles | PKI team | Logged |
| Change CRL endpoints | PKI team | Logged |
| Change OCSP trust | Security team | Mandatory |

## Compliance Controls

### SOC 2

- [ ] Audit logs retained 1 year
- [ ] Access reviews quarterly
- [ ] Encryption at rest and in transit
- [ ] Change management process

### PCI DSS

- [ ] CA keys in HSM
- [ ] Key rotation procedures
- [ ] Access control (2-of-3 for Root CA)
- [ ] Audit trail for all CA operations

### HIPAA

- [ ] Encryption of ePHI
- [ ] Access controls
- [ ] Audit logs (6 years)
- [ ] Business Associate Agreements

## Security Monitoring

### Alerts

| Alert | Severity | Response |
|-------|----------|----------|
| CA certificate expiring in 30 days | Warning | Review renewal process |
| CA certificate expiring in 7 days | Critical | Immediate renewal |
| Failed CA operations | Critical | Investigate immediately |
| Unauthorized access to Key Vault | Critical | Rotate credentials, investigate |
| HSM unavailable | Critical | Failover to secondary HSM |
| CRL not published in 24h | Warning | Check EJBCA scheduler |
| OCSP responder down | Critical | Restart service, investigate |

### Logging

All security events logged to:
- Azure Monitor (Log Analytics)
- Splunk/ELK (if configured)
- OpenBao audit log

**Retention**: 7 years for CA operations, 1 year for access logs.

## Incident Response

### CA Compromise

1. **Immediate**: Revoke CA certificate, publish CRL
2. **Short-term**: Issue new CA, re-issue certificates
3. **Long-term**: Investigate root cause, update controls

### Key Vault Breach

1. **Immediate**: Rotate all secrets, revoke access
2. **Short-term**: Audit access logs, identify scope
3. **Long-term**: Review access policies, enable additional controls

### HSM Failure

1. **Immediate**: Failover to secondary HSM
2. **Short-term**: Restore primary HSM
3. **Long-term**: Review HSM redundancy, update procedures
