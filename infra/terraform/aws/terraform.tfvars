# AWS Terraform Variables for Pipeline Deployment
aws_region       = "us-east-1"
environment      = "dev"
instance_type    = "t3.micro"
vpc_cidr         = "10.1.0.0/16"
subnet_cidr      = "10.1.1.0/24"
root_volume_size = 20
allowed_ssh_cidr = "0.0.0.0/0"
project_name     = "homelab"
