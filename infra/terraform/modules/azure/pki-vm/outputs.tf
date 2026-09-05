output "id" {
  description = "PKI VM ID"
  value       = module.vm.id
}

output "name" {
  description = "PKI VM name"
  value       = module.vm.name
}

output "private_ip" {
  description = "Private IP address of the PKI VM"
  value       = module.vm.private_ip
}

output "object" {
  description = "Full PKI VM object"
  value       = module.vm.object
}
