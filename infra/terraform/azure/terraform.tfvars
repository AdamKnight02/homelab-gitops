# Azure Terraform Variables
# Used by deploy-customer pipeline

azure_subscription_id = "c1873591-9690-48e4-a497-ef04eafdcc0e"
azure_region          = "eastus"
environment           = "dev"
vm_size               = "Standard_B1s"
vm_admin_username     = "ubuntu"
ssh_public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6Z37fYqBfcCknkKF69aB1YvW7YAwqwn4aPMYP06KsVPOcEGAYgfvufHelYjMp5HGPbHTBxYDzsZpG0uQXMA2ckenkn9C976aEWUZ94ukp2+uMNLURc+PpfaBkqPoykVNcUrSQfo1X6hAQZEly7Q0stc/kwGdC0iF2n89a4N2zqxXonIJMPRmIhRarOMaGjhU0iSnSgysIzMH8lH3rQyWgb2IhSbXr8+1LSeUdTRwXj5pHSNCZl62RtEtqIGfDE4dygw9w6yDE+JPM6OtCojn8UMnnIoDtVOhgQE3h128br1vP0T5ZzDiO9huIe2shF2SmiDUl+fQ/he1P46Bm5FP059xm9cGFBv3nCiKIEApdEN8aZkuQbG7Ad6sItJKFBHgmyVUyOMGU1yrbdXiH7RjySmQn2hc9G5dGHEhuppIPF1tzrJ6lBpOBQaUebIu2tvwn6XRLYHuPUPi6tDo/fvuUE1m3pNG/siyf6uji559jYaRuaMQ5ZyrrwUi5JQxdlAAVB364yTpxhO1JJPc42LGpGqJNMyW9Bv0b/jSUI4KZp2SQB47FtS1l672a5BMJPSvfzgnqUAypCMqHR6OToisPGStvWvqI4rqZwVyvLZPDVtfFYfaOL3i8Unbh905zrlJwFwhoMcsmOjtwX5J4lsWGMMWCwgaKjDSXNSL2ibf6Bw== azure-pipeline"
vnet_cidr             = "10.0.0.0/16"
subnet_cidr           = "10.0.1.0/24"
os_disk_size          = 30
project_name          = "pki-lab"
