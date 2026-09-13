# =============================================================================
# Azure Monitoring Bootstrap Module — Main Resources
# =============================================================================
# Creates Azure Monitor resources: Log Analytics workspace, Application
# Insights, and diagnostic settings. Standard/Enterprise tiers.
# =============================================================================

# ---------------------------------------------------------------------------
# Log Analytics Workspace
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_log_analytics ? 1 : 0

  name                = "${var.name}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Application Insights
# ---------------------------------------------------------------------------
resource "azurerm_application_insights" "main" {
  count = var.enable_app_insights ? 1 : 0

  name                = "${var.name}-appinsights"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = var.enable_log_analytics ? azurerm_log_analytics_workspace.main[0].id : null
  application_type    = "web"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Diagnostic Settings for VMs
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "vm" {
  count = var.enable_log_analytics ? length(var.vm_ids) : 0

  name                       = "${var.name}-vm-diag-${count.index}"
  target_resource_id         = var.vm_ids[count.index]
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------------------------------------------------------------------------
# Diagnostic Settings for NSG
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "nsg" {
  count = var.enable_log_analytics && var.enable_nsg_diagnostics ? 1 : 0

  name                       = "${var.name}-nsg-diag"
  target_resource_id         = var.nsg_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# ---------------------------------------------------------------------------
# Action Group for Alerts
# ---------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "main" {
  count = var.enable_log_analytics && var.alert_email != "" ? 1 : 0

  name                = "${var.name}-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "pki-alerts"
  tags                = var.tags

  email_receiver {
    name          = "admin"
    email_address = var.alert_email
  }
}

# ---------------------------------------------------------------------------
# Metric Alerts — VM CPU
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "vm_cpu" {
  count = var.enable_log_analytics ? length(var.vm_ids) : 0

  name                = "${var.name}-cpu-alert-${count.index}"
  resource_group_name = var.resource_group_name
  scopes              = [var.vm_ids[count.index]]
  description         = "Alert when VM CPU exceeds 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  dynamic "action" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.main[0].id
    }
  }
}
