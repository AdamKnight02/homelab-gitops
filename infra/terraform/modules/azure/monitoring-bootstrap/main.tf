resource "azurerm_log_analytics_workspace" "this" {
  name                = var.naming.log_analytics_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.config.retention_in_days
  tags                = var.tags
}

resource "azurerm_monitor_metric_alert" "this" {
  for_each = var.config.alerts

  name                = each.key
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_log_analytics_workspace.this.id]
  description         = "Alert for ${each.value.metric_name}"
  severity            = each.value.severity
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.OperationalInsights/workspaces"
    metric_name      = each.value.metric_name
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = each.value.threshold
  }
}
