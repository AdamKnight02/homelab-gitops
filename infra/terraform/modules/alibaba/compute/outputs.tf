# =============================================================================
# Alibaba Cloud Compute Module — Outputs
# =============================================================================

output "instance_ids" {
  description = "List of ECS instance IDs"
  value       = alicloud_instance.main[*].id
}

output "instance_names" {
  description = "List of ECS instance names"
  value       = alicloud_instance.main[*].instance_name
}

output "instance_private_ips" {
  description = "List of private IP addresses"
  value       = alicloud_instance.main[*].private_ip
}

output "instance_public_ips" {
  description = "List of public IP addresses (if any)"
  value       = alicloud_instance.main[*].public_ip
}

output "key_pair_name" {
  description = "Name of the SSH key pair used"
  value       = local.effective_key_name
}

output "ssh_private_key" {
  description = "Generated SSH private key (null if key_name or ssh_public_key was provided)"
  value       = local.create_key_pair && var.ssh_public_key == "" ? tls_private_key.ssh[0].private_key_openssh : null
  sensitive   = true
}

output "ssh_public_key" {
  description = "SSH public key used"
  value       = local.create_key_pair && var.ssh_public_key == "" ? tls_private_key.ssh[0].public_key_openssh : var.ssh_public_key
  sensitive   = false
}

output "zone_ids" {
  description = "Zone IDs where instances are deployed"
  value       = alicloud_instance.main[*].zone_id
}
