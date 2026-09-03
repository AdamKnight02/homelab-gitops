# Azure Outputs

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.name
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.main.ip_address
}

output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.main.private_ip_address
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${azurerm_public_ip.main.ip_address}"
}

output "k3s_kubeconfig" {
  description = "Command to copy kubeconfig"
  value       = "scp -i ~/.ssh/id_ed25519 ubuntu@${azurerm_public_ip.main.ip_address}:/etc/rancher/k3s/k3s.yaml ./azure-k3s.yaml"
}
