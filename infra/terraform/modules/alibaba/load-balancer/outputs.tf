# =============================================================================
# Alibaba Cloud Load Balancer Module — Outputs
# =============================================================================

output "slb_id" {
  description = "ID of the SLB (if created)"
  value       = var.create_slb && var.slb_type == "slb" ? alicloud_slb_load_balancer.main[0].id : null
}

output "slb_address" {
  description = "Address of the SLB (if created)"
  value       = var.create_slb && var.slb_type == "slb" ? alicloud_slb_load_balancer.main[0].address : null
}

output "nlb_id" {
  description = "ID of the NLB (if created)"
  value       = var.create_slb && var.slb_type == "nlb" ? alicloud_nlb_load_balancer.main[0].id : null
}

output "nlb_dns_name" {
  description = "DNS name of the NLB (if created)"
  value       = var.create_slb && var.slb_type == "nlb" ? alicloud_nlb_load_balancer.main[0].dns_name : null
}

output "load_balancer_address" {
  description = "Load balancer address (SLB or NLB)"
  value       = var.create_slb ? (var.slb_type == "slb" ? alicloud_slb_load_balancer.main[0].address : alicloud_nlb_load_balancer.main[0].dns_name) : null
}
