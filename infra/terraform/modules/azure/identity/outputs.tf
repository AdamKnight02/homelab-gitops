output "identity_ids" {
  description = "Map of identity names to IDs"
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.id }
}

output "identity_principal_ids" {
  description = "Map of identity names to principal IDs"
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.principal_id }
}

output "object" {
  description = "Full identity objects"
  value       = azurerm_user_assigned_identity.this
}
