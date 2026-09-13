# =============================================================================
# AWS Root Module — Outputs
# =============================================================================
# Outputs for the AWS PKI lab deployment.
# Tier-aware: economy outputs differ from standard/enterprise outputs.
# =============================================================================

# ---------------------------------------------------------------------------
# Common Outputs (all tiers)
# ---------------------------------------------------------------------------
output "cloud_provider" {
  description = "The cloud provider for this deployment."
  value       = "aws"
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
  description = "ID of the AWS VPC."
  value       = local.use_tier_modules ? module.network[0].vpc_id : aws_vpc.main[0].id
}

output "vpc_cidr" {
  description = "CIDR block of the AWS VPC."
  value       = local.use_tier_modules ? module.network[0].vpc_cidr : aws_vpc.main[0].cidr_block
}

output "subnet_id" {
  description = "ID of the primary subnet (economy: single subnet; standard+: first public subnet)."
  value       = local.use_tier_modules ? module.network[0].public_subnet_ids[0] : aws_subnet.main[0].id
}

output "subnet_cidr" {
  description = "CIDR block of the primary subnet."
  value       = local.use_tier_modules ? module.network[0].public_subnet_cidrs[0] : aws_subnet.main[0].cidr_block
}

output "instance_id" {
  description = "ID of the primary EC2 instance (economy: single instance; standard+: server node)."
  value       = local.use_tier_modules ? module.compute[0].server_instance_id : aws_instance.main[0].id
}

output "instance_name" {
  description = "Name tag of the primary EC2 instance."
  value       = local.use_tier_modules ? "${local.name_prefix}-k3s-0-${local.name_suffix}" : local.instance_name
}

output "instance_private_ip" {
  description = "Private IP address of the primary EC2 instance."
  value       = local.use_tier_modules ? module.compute[0].server_private_ip : aws_instance.main[0].private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the primary EC2 instance (if associated)."
  value       = var.aws_associate_public_ip ? (local.use_tier_modules ? module.compute[0].server_public_ip : aws_instance.main[0].public_ip) : null
}

output "security_group_id" {
  description = "ID of the primary security group."
  value       = local.use_tier_modules ? module.security[0].k3s_security_group_id : aws_security_group.main[0].id
}

output "iam_role_arn" {
  description = "ARN of the IAM role."
  value       = local.use_tier_modules ? module.identity[0].role_arn : (var.aws_create_iam_role ? aws_iam_role.main[0].arn : null)
}

# ---------------------------------------------------------------------------
# Standard/Enterprise Tier Outputs (module composition)
# ---------------------------------------------------------------------------
output "instance_ids" {
  description = "IDs of all EC2 instances (standard/enterprise only)."
  value       = local.use_tier_modules ? module.compute[0].instance_ids : []
}

output "instance_private_ips" {
  description = "Private IPs of all EC2 instances (standard/enterprise only)."
  value       = local.use_tier_modules ? module.compute[0].instance_private_ips : []
}

output "instance_public_ips" {
  description = "Public IPs of all EC2 instances (standard/enterprise only)."
  value       = local.use_tier_modules ? module.compute[0].instance_public_ips : []
}

output "private_subnet_ids" {
  description = "IDs of private subnets (enterprise only)."
  value       = local.use_tier_modules ? module.network[0].private_subnet_ids : []
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways (enterprise only)."
  value       = local.use_tier_modules ? module.network[0].nat_gateway_ids : []
}

output "lb_dns_name" {
  description = "DNS name of the load balancer (standard/enterprise only)."
  value       = local.use_tier_modules ? module.load_balancer[0].lb_dns_name : null
}

output "k3s_api_endpoint" {
  description = "K3s API endpoint via load balancer (standard/enterprise only)."
  value       = local.use_tier_modules ? module.load_balancer[0].k3s_api_endpoint : null
}

output "db_endpoint" {
  description = "RDS database endpoint (standard/enterprise only)."
  value       = local.use_tier_modules ? module.database[0].db_endpoint : null
}

output "db_connection_string" {
  description = "RDS database connection string (standard/enterprise only, sensitive)."
  value       = local.use_tier_modules ? module.database[0].db_connection_string : null
  sensitive   = true
}

output "s3_bucket_id" {
  description = "S3 bucket ID for backups (standard/enterprise only)."
  value       = local.use_tier_modules ? module.storage[0].s3_bucket_id : null
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption at rest (enterprise only)."
  value       = local.use_tier_modules ? module.secrets[0].kms_key_arn : null
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
    ec2_instances   = 1
    ebs_volumes     = 1
    ebs_total_gb    = var.aws_root_volume_size
    nat_gateways    = 0
    public_ips      = var.aws_associate_public_ip ? 1 : 0
    rds_instances   = 0
    rds_multi_az    = false
    eks_clusters    = 0
    load_balancers  = 0
    s3_buckets      = 0
    kms_keys        = 0
    secrets_manager = 0
  }
}

output "cost_guardrail_summary" {
  description = "Human-readable cost guardrail summary. Review before applying."
  value = local.use_tier_modules ? join("\n", [
    "=== COST GUARDRAIL SUMMARY (${upper(var.service_tier)} tier) ===",
    "EC2 Instances:    ${module.tier_config[0].cost_report.ec2_instances}",
    "EBS Volumes:      ${module.tier_config[0].cost_report.ebs_volumes} (${module.tier_config[0].cost_report.ebs_total_gb} GB total)",
    "NAT Gateways:     ${module.tier_config[0].cost_report.nat_gateways}${module.tier_config[0].cost_report.nat_gateways > 0 ? " ⚠️  COST: ~$32/month each" : ""}",
    "Public IPs:       ${module.tier_config[0].cost_report.public_ips}${module.tier_config[0].cost_report.public_ips > 0 ? " ⚠️  COST: ~$3.60/month each" : ""}",
    "RDS Instances:    ${module.tier_config[0].cost_report.rds_instances}${module.tier_config[0].cost_report.rds_instances > 0 ? " ⚠️  COST: ~$15-60/month" : ""}",
    "RDS Multi-AZ:     ${module.tier_config[0].cost_report.rds_multi_az}",
    "EKS Clusters:     ${module.tier_config[0].cost_report.eks_clusters}${module.tier_config[0].cost_report.eks_clusters > 0 ? " ⚠️  COST: ~$73/month" : ""}",
    "Load Balancers:   ${module.tier_config[0].cost_report.load_balancers}${module.tier_config[0].cost_report.load_balancers > 0 ? " ⚠️  COST: ~$16/month" : ""}",
    "S3 Buckets:       ${module.tier_config[0].cost_report.s3_buckets}",
    "KMS Keys:         ${module.tier_config[0].cost_report.kms_keys}",
    "Secrets Manager:  ${module.tier_config[0].cost_report.secrets_manager}",
    "",
    "Estimated Monthly Cost: ~$${module.tier_config[0].estimated_monthly_cost}",
    "=============================================="
    ]) : join("\n", [
    "=== COST GUARDRAIL SUMMARY (ECONOMY tier) ===",
    "EC2 Instances:    1",
    "EBS Volumes:      1 (${var.aws_root_volume_size} GB)",
    "NAT Gateways:     0",
    "Public IPs:       ${var.aws_associate_public_ip ? 1 : 0}${var.aws_associate_public_ip ? " ⚠️  COST: ~$3.60/month" : ""}",
    "RDS Instances:    0",
    "EKS Clusters:     0",
    "Load Balancers:   0",
    "S3 Buckets:       0",
    "KMS Keys:         0",
    "Secrets Manager:  0",
    "",
    "Estimated Monthly Cost: ~$${local.estimated_monthly_cost_usd}",
    "=============================================="
  ])
}

# ---------------------------------------------------------------------------
# Security Notes
# ---------------------------------------------------------------------------
output "security_notes" {
  description = "Security reminders for this deployment."
  value       = <<-EOT
    AWS SECURITY NOTES (${upper(var.service_tier)} tier):
    - EC2 has no public IP by default; use AWS Systems Manager Session Manager for access
    - Security group denies all inbound traffic by default
    - SSH key is auto-generated; store it securely
    - IAM role has minimal permissions (SSM, CloudWatch read-only)
    - All resources are tagged for easy identification and cleanup
    - Terraform state contains sensitive data; do not commit it
    %{if local.use_tier_modules~}
    - Tier: ${var.service_tier} — ${module.tier_config[0].cost_report.ec2_instances} instances
    - NAT Gateways: ${module.tier_config[0].cost_report.nat_gateways} (should be 0 for economy)
    - RDS: ${module.tier_config[0].cost_report.rds_instances} instance(s) (should be 0 for economy)
    - Load Balancers: ${module.tier_config[0].cost_report.load_balancers} (should be 0 for economy)
    %{endif~}
    EOT
}
