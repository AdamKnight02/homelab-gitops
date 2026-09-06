# Azure Terraform Variables
# Used by deploy-customer pipeline

azure_subscription_id = "c1873591-9690-48e4-a497-ef04eafdcc0e"
azure_region          = "eastus"
environment           = "dev"
vm_size               = "Standard_B1s"
vm_admin_username     = "ubuntu"
ssh_public_key        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID10ighVj+GBJsGw7HW9dF8COz0epHHn+sIjuklsNJyt openclaw@frostnode"
vnet_cidr             = "10.0.0.0/16"
subnet_cidr           = "10.0.1.0/24"
os_disk_size          = 30
project_name          = "pki-lab"
