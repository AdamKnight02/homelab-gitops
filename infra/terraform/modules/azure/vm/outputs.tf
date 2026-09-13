output "id" {
  description = "VM ID"
  value       = azurerm_linux_virtual_machine.this.id
}

output "name" {
  description = "VM name"
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.this.private_ip_address
}

output "object" {
  description = "Full VM and NIC objects"
  value = {
    vm  = azurerm_linux_virtual_machine.this
    nic = azurerm_network_interface.this
  }
}
