# =============================================================================
# Contract Validation Module — Outputs
# =============================================================================
# These outputs expose the contract version and validation results.
# =============================================================================

output "provider_contract_version" {
  description = "The contract version implemented by this module."
  value       = local.provider_contract_version
}

output "required_tags" {
  description = "List of required tags for all resources."
  value       = local.required_tags
}

output "required_outputs" {
  description = "List of required outputs for all providers."
  value       = local.required_outputs
}

output "required_inputs" {
  description = "List of required inputs for all providers."
  value       = local.required_inputs
}

output "valid_tiers" {
  description = "List of valid service tiers."
  value       = local.valid_tiers
}

output "naming_patterns" {
  description = "Naming convention patterns per provider."
  value       = local.naming_patterns
}

output "tier_capabilities" {
  description = "Tier capability matrix."
  value       = local.tier_capabilities
}
