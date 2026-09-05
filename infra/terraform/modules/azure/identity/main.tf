resource "azurerm_user_assigned_identity" "this" {
  for_each = var.config.identities

  name                = lookup(var.naming.identity_names, each.key, each.key)
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Flatten role assignments across all identities
locals {
  role_assignments = flatten([
    for identity_key, identity in var.config.identities : [
      for ra in identity.role_assignments : {
        key      = "${identity_key}-${ra.role}-${replace(ra.scope, "/", "-")}"
        identity = identity_key
        scope    = ra.scope
        role     = ra.role
      }
    ]
  ])
}

resource "azurerm_role_assignment" "this" {
  for_each = { for ra in local.role_assignments : ra.key => ra }

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this[each.value.identity].principal_id
}
