resource "azurerm_automation_account" "this" {
  name                = var.naming.automation_account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.config.sku_name
  tags                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = var.identity_ids
  }
}

resource "azurerm_automation_runbook" "this" {
  for_each = var.config.runbooks

  name                    = each.key
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = each.value.type
  content                 = each.value.content
  tags                    = var.tags
}

resource "azurerm_automation_schedule" "this" {
  for_each = var.config.schedules

  name                    = each.key
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = each.value.frequency
  interval                = each.value.interval
  start_time              = each.value.start_time
  timezone                = "UTC"
}
