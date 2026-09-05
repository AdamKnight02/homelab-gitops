output "id" {
  description = "Automation account ID"
  value       = azurerm_automation_account.this.id
}

output "name" {
  description = "Automation account name"
  value       = azurerm_automation_account.this.name
}

output "object" {
  description = "Full automation account object"
  value       = azurerm_automation_account.this
}
