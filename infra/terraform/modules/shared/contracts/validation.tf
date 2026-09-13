# =============================================================================
# Contract Validation Logic
# =============================================================================
# Validates that a provider implementation conforms to the v1 contract.
# Produces validation results and error messages for any violations.
# =============================================================================

locals {
  # -------------------------------------------------------------------------
  # Tag Validation
  # -------------------------------------------------------------------------
  missing_required_tags = [
    for tag in local.required_tags : tag
    if !contains(keys(var.tags), tag)
  ]

  tags_valid = length(local.missing_required_tags) == 0

  # -------------------------------------------------------------------------
  # Output Validation
  # -------------------------------------------------------------------------
  missing_required_outputs = [
    for output in local.required_outputs : output
    if !lookup(var.outputs, output, false)
  ]

  outputs_valid = length(local.missing_required_outputs) == 0

  # -------------------------------------------------------------------------
  # Input Validation
  # -------------------------------------------------------------------------
  missing_required_inputs = [
    for input in local.required_inputs : input
    if !lookup(var.inputs, input, false)
  ]

  inputs_valid = length(local.missing_required_inputs) == 0

  # -------------------------------------------------------------------------
  # Tier Validation
  # -------------------------------------------------------------------------
  tier_valid = contains(local.valid_tiers, lower(var.service_tier))

  # -------------------------------------------------------------------------
  # Instance Count Validation (tier-aware)
  # -------------------------------------------------------------------------
  tier_caps = local.tier_capabilities[lower(var.service_tier)]

  instance_count_valid = (
    var.instance_count >= local.tier_caps.min_instances &&
    var.instance_count <= local.tier_caps.max_instances
  )

  # -------------------------------------------------------------------------
  # Feature/Tier Compatibility Validation
  # -------------------------------------------------------------------------
  feature_violations = [
    for feature, enabled in var.features_enabled :
    feature if enabled && !lookup(local.tier_caps, "allow_${feature}", true)
  ]

  features_valid = length(local.feature_violations) == 0

  # -------------------------------------------------------------------------
  # Naming Convention Validation
  # -------------------------------------------------------------------------
  # Check that resource names follow the expected pattern for the provider
  naming_pattern = local.naming_patterns[var.provider_name]

  naming_violations = [
    for resource_type, name in var.resource_names :
    resource_type if !can(regex("^${replace(replace(local.naming_pattern[resource_type], "{prefix}", ".*"), "{suffix}", ".*")}$", name))
  ]

  naming_valid = length(local.naming_violations) == 0

  # -------------------------------------------------------------------------
  # Overall Contract Compliance
  # -------------------------------------------------------------------------
  contract_compliant = (
    local.tags_valid &&
    local.outputs_valid &&
    local.inputs_valid &&
    local.tier_valid &&
    local.instance_count_valid &&
    local.features_valid &&
    local.naming_valid
  )

  # -------------------------------------------------------------------------
  # Validation Report
  # -------------------------------------------------------------------------
  validation_report = {
    contract_version = local.provider_contract_version
    provider         = var.provider_name
    service_tier     = var.service_tier
    compliant        = local.contract_compliant
    checks = {
      tags = {
        valid   = local.tags_valid
        missing = local.missing_required_tags
      }
      outputs = {
        valid   = local.outputs_valid
        missing = local.missing_required_outputs
      }
      inputs = {
        valid   = local.inputs_valid
        missing = local.missing_required_inputs
      }
      tier = {
        valid = local.tier_valid
        value = var.service_tier
      }
      instance_count = {
        valid    = local.instance_count_valid
        actual   = var.instance_count
        expected = "${local.tier_caps.min_instances}-${local.tier_caps.max_instances}"
      }
      features = {
        valid      = local.features_valid
        violations = local.feature_violations
      }
      naming = {
        valid      = local.naming_valid
        violations = local.naming_violations
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Validation Outputs
# -----------------------------------------------------------------------------
output "contract_compliant" {
  description = "Whether the provider implementation is fully contract-compliant."
  value       = local.contract_compliant
}

output "validation_report" {
  description = "Detailed validation report."
  value       = local.validation_report
}

output "missing_tags" {
  description = "List of missing required tags."
  value       = local.missing_required_tags
}

output "missing_outputs" {
  description = "List of missing required outputs."
  value       = local.missing_required_outputs
}

output "missing_inputs" {
  description = "List of missing required inputs."
  value       = local.missing_required_inputs
}

output "feature_violations" {
  description = "List of features enabled that are not allowed in the current tier."
  value       = local.feature_violations
}

output "naming_violations" {
  description = "List of resource names that do not follow naming conventions."
  value       = local.naming_violations
}
