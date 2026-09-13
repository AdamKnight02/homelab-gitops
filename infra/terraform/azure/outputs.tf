# =============================================================================
# Azure Root Module — Outputs
# =============================================================================
# Outputs for the Azure PKI platform deployment.
# Tier-aware: outputs change based on service_tier.
# =============================================================================

output "cloud_provider" {
  description = "The cloud provider for this deployment."
  value       = "azure"
}

output "service_tier" {
  description = "The service tier for this deployment."
  value       = local.tier
}

output "resource_group_name" {
  description = "Name of the Azure Resource Group."
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the Azure Resource Group."
  value       = azurerm_resource_group.main.id
}

output "location" {
  description = "Azure region where resources are deployed."
  value       = var.azure_region
}

output "vnet_name" {
  description = "Name of the Azure Virtual Network."
  value       = azurerm_virtual_network.main.name
}

output "vnet_id" {
  description = "ID of the Azure Virtual Network."
  value       = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "Map of subnet names to IDs."
  value       = { for k, v in azurerm_subnet.main : k => v.id }
}

# ---------------------------------------------------------------------------
# Economy Tier Outputs (single VM)
# ---------------------------------------------------------------------------
output "vm_name" {
  description = "Name of the Azure VM (economy tier)."
  value       = local.tier == "economy" ? azurerm_linux_virtual_machine.main[0].name : null
}

output "vm_id" {
  description = "ID of the Azure VM (economy tier)."
  value       = local.tier == "economy" ? azurerm_linux_virtual_machine.main[0].id : null
}

output "vm_private_ip" {
  description = "Private IP address of the Azure VM (economy tier)."
  value       = local.tier == "economy" ? azurerm_linux_virtual_machine.main[0].private_ip_address : null
}

output "vm_public_ip" {
  description = "Public IP address of the Azure VM (economy tier, if allocated)."
  value       = local.tier == "economy" && var.azure_public_ip_enabled ? azurerm_public_ip.main[0].ip_address : null
}

# ---------------------------------------------------------------------------
# Standard/Enterprise Tier Outputs (multi-VM)
# ---------------------------------------------------------------------------
output "vm_names" {
  description = "Names of all Azure VMs (standard/enterprise tier)."
  value       = local.tier != "economy" ? module.compute[0].vm_names : []
}

output "vm_ids" {
  description = "IDs of all Azure VMs (standard/enterprise tier)."
  value       = local.tier != "economy" ? module.compute[0].vm_ids : []
}

output "vm_private_ips" {
  description = "Private IPs of all Azure VMs (standard/enterprise tier)."
  value       = local.tier != "economy" ? module.compute[0].vm_private_ips : []
}

output "vm_public_ips" {
  description = "Public IPs of all Azure VMs (standard/enterprise tier, if allocated)."
  value       = local.tier != "economy" ? module.compute[0].vm_public_ips : []
}

# ---------------------------------------------------------------------------
# Shared Outputs
# ---------------------------------------------------------------------------
output "ssh_private_key" {
  description = "Private SSH key for VM access (sensitive)."
  value       = tls_private_key.ssh.private_key_openssh
  sensitive   = true
}

output "ssh_public_key" {
  description = "Public SSH key for VM access."
  value       = tls_private_key.ssh.public_key_openssh
  sensitive   = false
}

output "k3s_token" {
  description = "K3s cluster token for multi-node join (sensitive)."
  value       = local.k3s_token_resolved
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Load Balancer Outputs
# ---------------------------------------------------------------------------
output "lb_public_ip" {
  description = "Public IP of the load balancer (if enabled)."
  value       = local.load_balancer_type != "none" ? module.load_balancer[0].lb_public_ip : null
}

# ---------------------------------------------------------------------------
# Database Outputs
# ---------------------------------------------------------------------------
output "database_fqdn" {
  description = "FQDN of the PostgreSQL server (if enabled)."
  value       = local.database_mode != "container" ? module.database[0].server_fqdn : null
}

output "database_connection_string" {
  description = "PostgreSQL connection string (sensitive)."
  value       = local.database_mode != "container" ? module.database[0].connection_string : null
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Storage Outputs
# ---------------------------------------------------------------------------
output "storage_account_name" {
  description = "Name of the storage account (if enabled)."
  value       = local.storage_account_enabled ? module.storage[0].storage_account_name : null
}

# ---------------------------------------------------------------------------
# Key Vault Outputs
# ---------------------------------------------------------------------------
output "key_vault_uri" {
  description = "URI of the Key Vault (if enabled)."
  value       = local.key_vault_enabled ? module.secrets[0].key_vault_uri : null
}

# ---------------------------------------------------------------------------
# Managed Identity Outputs
# ---------------------------------------------------------------------------
output "managed_identity_client_id" {
  description = "Client ID of the managed identity (if enabled)."
  value       = local.managed_identity_enabled ? module.identity[0].identity_client_id : null
}

# ---------------------------------------------------------------------------
# Cost and Guardrail Outputs
# ---------------------------------------------------------------------------
output "estimated_monthly_cost_usd" {
  description = "Estimated monthly cost if left running."
  value       = local.estimated_monthly_cost
}

output "cost_report" {
  description = "Resource count report for cost guardrails."
  value       = local.cost_report
}

# ---------------------------------------------------------------------------
# Resource Count Guard: EXPECTED vs ACTUAL
# ---------------------------------------------------------------------------
# This output provides a structured comparison of what the tier-config
# expects to create vs. what the root module actually wires. Use this
# to validate that no resources are missing or unexpected before apply.

output "resource_count_guard" {
  description = "EXPECTED vs ACTUAL resource counts for plan validation."
  value = {
    # --- EXPECTED (from tier-config) ---
    expected = {
      vms                = local.vm_count
      vm_size            = local.vm_size
      database_servers   = local.database_mode != "container" ? 1 : 0
      database_ha        = local.database_mode == "azure-flexible-ha"
      storage_accounts   = local.storage_account_enabled ? 1 : 0
      key_vaults         = local.key_vault_enabled ? 1 : 0
      public_ips         = var.azure_public_ip_enabled ? local.vm_count : 0
      load_balancers     = local.load_balancer_type != "none" ? 1 : 0
      app_gateways       = local.app_gateway_enabled ? 1 : 0
      monitoring         = local.log_analytics_enabled ? 1 : 0
      app_insights       = local.app_insights_enabled ? 1 : 0
      managed_identities = local.managed_identity_enabled ? 1 : 0
      nat_gateways       = local.enable_nat_gateway ? 1 : 0
      # PKI protocol endpoints (deployed on K3s, not Azure resources)
      scep_enabled = true # Always enabled via K3s cert-manager
      acme_enabled = true # Always enabled via K3s cert-manager
      external_ca  = local.tier == "enterprise" ? true : false
    }

    # --- ACTUAL (from root module wiring) ---
    actual = {
      vms = (
        local.tier == "economy" ? length(azurerm_linux_virtual_machine.main) :
        local.tier != "economy" ? local.vm_count : 0
      )
      database_servers = length(module.database)
      storage_accounts = length(module.storage)
      key_vaults       = length(module.secrets)
      public_ips = (
        local.tier == "economy" ? length(azurerm_public_ip.main) :
        local.tier != "economy" && var.azure_public_ip_enabled ? local.vm_count : 0
      )
      load_balancers     = length(module.load_balancer)
      app_gateways       = local.app_gateway_enabled ? 1 : 0
      monitoring         = length(module.monitoring)
      app_insights       = local.app_insights_enabled ? 1 : 0
      managed_identities = length(module.identity)
      nat_gateways       = 0 # Not wired in root module (opt-in via network module)
      # PKI protocol endpoints
      scep_enabled = true # Deployed via K3s manifests
      acme_enabled = true # Deployed via K3s manifests
      external_ca  = local.tier == "enterprise" ? true : false
    }

    # --- VALIDATION ---
    validation = {
      vms_match = (
        (local.tier == "economy" ? length(azurerm_linux_virtual_machine.main) : local.tier != "economy" ? local.vm_count : 0) == local.vm_count
      )
      database_match         = length(module.database) == (local.database_mode != "container" ? 1 : 0)
      storage_match          = length(module.storage) == (local.storage_account_enabled ? 1 : 0)
      key_vault_match        = length(module.secrets) == (local.key_vault_enabled ? 1 : 0)
      load_balancer_match    = length(module.load_balancer) == (local.load_balancer_type != "none" ? 1 : 0)
      monitoring_match       = length(module.monitoring) == (local.log_analytics_enabled ? 1 : 0)
      managed_identity_match = length(module.identity) == (local.managed_identity_enabled ? 1 : 0)
      all_match = (
        (local.tier == "economy" ? length(azurerm_linux_virtual_machine.main) : local.tier != "economy" ? local.vm_count : 0) == local.vm_count &&
        length(module.database) == (local.database_mode != "container" ? 1 : 0) &&
        length(module.storage) == (local.storage_account_enabled ? 1 : 0) &&
        length(module.secrets) == (local.key_vault_enabled ? 1 : 0) &&
        length(module.load_balancer) == (local.load_balancer_type != "none" ? 1 : 0) &&
        length(module.monitoring) == (local.log_analytics_enabled ? 1 : 0) &&
        length(module.identity) == (local.managed_identity_enabled ? 1 : 0)
      )
    }
  }
}

output "security_notes" {
  description = "Security reminders for this deployment."
  value       = <<-EOT
    AZURE SECURITY NOTES (Tier: ${local.tier}):
    - VMs have no public IP by default; use Azure Serial Console or Bastion for access
    - NSG denies all inbound traffic by default
    - SSH key is auto-generated; store it securely
    - All resources are in a single resource group for easy cleanup
    - Terraform state contains sensitive data; do not commit it
    %{if local.tier == "economy"~}
    - Economy tier: single VM, no managed services, minimal cost
    %{endif~}
    %{if local.tier == "standard"~}
    - Standard tier: multi-node K3s, Azure Database, Load Balancer
    - Managed identity enabled for secure service-to-service auth
    %{endif~}
    %{if local.tier == "enterprise"~}
    - Enterprise tier: multi-zone, HA database, Key Vault, monitoring
    - Managed identity + Key Vault for secrets management
    - Log Analytics + Application Insights for observability
    %{endif~}
    EOT
}
