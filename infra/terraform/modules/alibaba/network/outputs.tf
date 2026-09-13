# =============================================================================
# Alibaba Cloud Network Module — Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = alicloud_vpc.main.id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = alicloud_vpc.main.vpc_name
}

output "vswitch_ids" {
  description = "Map of subnet names to VSwitch IDs"
  value       = { for k, v in alicloud_vswitch.main : k => v.id }
}

output "vswitch_cidrs" {
  description = "Map of subnet names to CIDR blocks"
  value       = { for k, v in alicloud_vswitch.main : k => v.cidr_block }
}

output "route_table_id" {
  description = "ID of the default route table"
  value       = alicloud_vpc.main.route_table_id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway (if created)"
  value       = var.enable_nat_gateway ? alicloud_nat_gateway.main[0].id : null
}

output "eip_address" {
  description = "Elastic IP address (if allocated)"
  value       = var.enable_eip ? alicloud_eip_address.main[0].ip_address : null
}

output "zone_ids" {
  description = "Zone IDs used for subnets"
  value       = [for v in alicloud_vswitch.main : v.zone_id]
}
