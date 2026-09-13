# =============================================================================
# Alibaba Cloud Root Module — Outputs
# =============================================================================
# Outputs for the Alibaba Cloud PKI platform deployment.
# Tier-aware: economy outputs differ from standard/enterprise outputs.
# =============================================================================

# ---------------------------------------------------------------------------
# Common Outputs (all tiers)
# ---------------------------------------------------------------------------
output "cloud_provider" {
  description = "The cloud provider for this deployment."
  value       = "alibaba"
}

output "service_tier" {
  description = "The service tier for this deployment."
  value       = lower(var.service_tier)
}

output "ssh_private_key" {
  description = "Private SSH key for instance access (sensitive)."
  value       = tls_private_key.ssh.private_key_openssh
  sensitive   = true
}

output "ssh_public_key" {
  description = "Public SSH key for instance access."
  value       = tls_private_key.ssh.public_key_openssh
  sensitive   = false
}

# ---------------------------------------------------------------------------
# Economy Tier Outputs (inline resources)
# ---------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC."
  value       = local.use_tier_modules ? module.network[0].vpc_id : alicloud_vpc.main[0].id
}

output "vpc_name" {
  description = "Name of the VPC."
  value       = local.use_tier_modules ? module.network[0].vpc_name : alicloud_vpc.main[0].vpc_name
}

output "vswitch_id" {
  description = "ID of the primary VSwitch (economy: single; standard+: first)."
  value       = local.use_tier_modules ? module.network[0].vswitch_ids["main"] : alicloud_vswitch.main[0].id
}

output "instance_id" {
  description = "ID of the primary ECS instance (economy: single; standard+: server node)."
  value       = local.use_tier_modules ? module.compute[0].instance_ids[0] : alicloud_instance.main[0].id
}

output "instance_name" {
  description = "Name of the primary ECS instance."
  value       = local.use_tier_modules ? module.compute[0].instance_names[0] : local.instance_name
}

output "instance_private_ip" {
  description = "Private IP address of the primary ECS instance."
  value       = local.use_tier_modules ? module.compute[0].instance_private_ips[0] : alicloud_instance.main[0].private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the primary ECS instance (if associated)."
  value       = var.alibaba_associate_public_ip ? (local.use_tier_modules ? module.compute[0].instance_public_ips[0] : alicloud_instance.main[0].public_ip) : null
}

output "security_group_id" {
  description = "ID of the primary security group."
  value       = local.use_tier_modules ? module.security[0].security_group_id : alicloud_security_group.main[0].id
}

output "ram_role_name" {
  description = "Name of the RAM role."
  value       = local.use_tier_modules ? module.identity[0].ram_role_name : (var.alibaba_create_ram_role ? alicloud_ram_role.main[0].role_name : null)
}

# ---------------------------------------------------------------------------
# Standard/Enterprise Tier Outputs (module composition)
# ---------------------------------------------------------------------------
output "instance_ids" {
  description = "IDs of all ECS instances (standard/enterprise only)."
  value       = local.use_tier_modules ? module.compute[0].instance_ids : []
}

output "instance_private_ips" {
  description = "Private IPs of all ECS instances (standard/enterprise only)."
  value       = local.use_tier_modules ? module.compute[0].instance_private_ips : []
}

output "instance_public_ips" {
  description = "Public IPs of all ECS instances (standard/enterprise only)."
  value       = local.use_tier_modules ? module.compute[0].instance_public_ips : []
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (enterprise only)."
  value       = local.use_tier_modules ? module.network[0].nat_gateway_id : null
}

output "eip_address" {
  description = "Elastic IP address (enterprise only)."
  value       = local.use_tier_modules ? module.network[0].eip_address : null
}

output "load_balancer_address" {
  description = "Load balancer address (standard/enterprise only)."
  value       = local.use_tier_modules ? module.load_balancer[0].load_balancer_address : null
}

output "rds_instance_id" {
  description = "RDS instance ID (standard/enterprise only)."
  value       = local.use_tier_modules ? module.database[0].rds_instance_id : null
}

output "rds_connection_string" {
  description = "RDS connection string (standard/enterprise only, sensitive)."
  value       = local.use_tier_modules ? module.database[0].database_connection_string : null
  sensitive   = true
}

output "oss_bucket_name" {
  description = "OSS bucket name (standard/enterprise only)."
  value       = local.use_tier_modules ? module.storage[0].oss_bucket_name : null
}

output "kms_key_id" {
  description = "KMS key ID (enterprise only)."
  value       = local.use_tier_modules ? module.secrets[0].kms_key_id : null
}

# ---------------------------------------------------------------------------
# Cost Guardrail Outputs
# ---------------------------------------------------------------------------
output "estimated_monthly_cost_usd" {
  description = "Estimated monthly cost if left running."
  value       = local.use_tier_modules ? module.tier_config[0].estimated_monthly_cost : local.estimated_monthly_cost_usd
}

output "cost_report" {
  description = "Resource count summary for cost guardrail review before apply."
  value = local.use_tier_modules ? module.tier_config[0].cost_report : {
    ecs_instances   = 1
    disks           = 1
    disk_total_gb   = var.alibaba_root_volume_size
    nat_gateways    = 0
    eip_addresses   = 0
    public_ips      = var.alibaba_associate_public_ip ? 1 : 0
    rds_instances   = 0
    rds_multi_zone  = false
    ack_clusters    = 0
    load_balancers  = 0
    oss_buckets     = 0
    kms_keys        = 0
    secrets_manager = 0
  }
}

output "cost_guardrail_summary" {
  description = "Human-readable cost guardrail summary. Review before applying."
  value = local.use_tier_modules ? join("\n", [
    "=== COST GUARDRAIL SUMMARY (${upper(var.service_tier)} tier) — Alibaba Cloud ===",
    "ECS Instances:     ${module.tier_config[0].cost_report.ecs_instances}",
    "Disks:             ${module.tier_config[0].cost_report.disks} (${module.tier_config[0].cost_report.disk_total_gb} GB total)",
    "NAT Gateways:      ${module.tier_config[0].cost_report.nat_gateways}${module.tier_config[0].cost_report.nat_gateways > 0 ? " ⚠️  COST: ~$30/month" : ""}",
    "EIP Addresses:     ${module.tier_config[0].cost_report.eip_addresses}${module.tier_config[0].cost_report.eip_addresses > 0 ? " ⚠️  COST: ~$3/month" : ""}",
    "Public IPs:        ${module.tier_config[0].cost_report.public_ips}${module.tier_config[0].cost_report.public_ips > 0 ? " ⚠️  COST: ~$3/month each" : ""}",
    "RDS Instances:     ${module.tier_config[0].cost_report.rds_instances}${module.tier_config[0].cost_report.rds_instances > 0 ? " ⚠️  COST: ~$20-80/month" : ""}",
    "RDS Multi-Zone:    ${module.tier_config[0].cost_report.rds_multi_zone}",
    "ACK Clusters:      ${module.tier_config[0].cost_report.ack_clusters}${module.tier_config[0].cost_report.ack_clusters > 0 ? " ⚠️  COST: ~$70/month" : ""}",
    "Load Balancers:    ${module.tier_config[0].cost_report.load_balancers}${module.tier_config[0].cost_report.load_balancers > 0 ? " ⚠️  COST: ~$15/month" : ""}",
    "OSS Buckets:       ${module.tier_config[0].cost_report.oss_buckets}",
    "KMS Keys:          ${module.tier_config[0].cost_report.kms_keys}",
    "Secrets Manager:   ${module.tier_config[0].cost_report.secrets_manager}",
    "",
    "Estimated Monthly Cost: ~$${module.tier_config[0].estimated_monthly_cost}",
    "========================================================"
    ]) : join("\n", [
    "=== COST GUARDRAIL SUMMARY (ECONOMY tier) — Alibaba Cloud ===",
    "ECS Instances:     1",
    "Disks:             1 (${var.alibaba_root_volume_size} GB)",
    "NAT Gateways:      0",
    "EIP Addresses:     0",
    "Public IPs:        ${var.alibaba_associate_public_ip ? 1 : 0}${var.alibaba_associate_public_ip ? " ⚠️  COST: ~$3/month" : ""}",
    "RDS Instances:     0",
    "ACK Clusters:      0",
    "Load Balancers:    0",
    "OSS Buckets:       0",
    "KMS Keys:          0",
    "Secrets Manager:   0",
    "",
    "Estimated Monthly Cost: ~$${local.estimated_monthly_cost_usd}",
    "========================================================"
  ])
}

# ---------------------------------------------------------------------------
# Security Notes
# ---------------------------------------------------------------------------
output "security_notes" {
  description = "Security reminders for this deployment."
  value       = <<-EOT
    ALIBABA CLOUD SECURITY NOTES (${upper(var.service_tier)} tier):
    - ECS has no public IP by default; use Alibaba Cloud Workbench or bastion for access
    - Security group denies all inbound traffic by default
    - SSH key is auto-generated; store it securely
    - RAM role has minimal permissions
    - All resources are tagged for easy identification and cleanup
    - Terraform state contains sensitive data; do not commit it
    %{if local.use_tier_modules~}
    - Tier: ${var.service_tier} — ${module.tier_config[0].cost_report.ecs_instances} instances
    - NAT Gateways: ${module.tier_config[0].cost_report.nat_gateways} (should be 0 for economy)
    - RDS: ${module.tier_config[0].cost_report.rds_instances} instance(s) (should be 0 for economy)
    - Load Balancers: ${module.tier_config[0].cost_report.load_balancers} (should be 0 for economy)
    - ACK Clusters: ${module.tier_config[0].cost_report.ack_clusters} (should be 0 unless explicitly enabled)
    %{endif~}
    EOT
}
