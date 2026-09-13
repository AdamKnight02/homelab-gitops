# =============================================================================
# AWS Compute Module
# =============================================================================
# Tier-aware EC2 instances for K3s nodes.
# Economy: single t3.micro, public subnet.
# Standard: 3 × t3.medium, public subnet (cost-optimized, no private subnets).
# Enterprise: 6 × m6i.large, spread across AZs, private subnets for workers.
# =============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "name_prefix" { type = string }
variable "name_suffix" { type = string }
variable "service_tier" { type = string }
variable "instance_count" { type = number }
variable "instance_type" { type = string }
variable "ami_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "key_name" { type = string }
variable "iam_instance_profile" { type = string }
variable "associate_public_ip" { type = bool }
variable "enable_monitoring" { type = bool }
variable "root_volume_size" { type = number }
variable "root_volume_type" { type = string }
variable "user_data" { type = string }
variable "availability_zones" { type = list(string) }
variable "tags" { type = map(string) }

# ---------------------------------------------------------------------------
# EC2 Instances
# ---------------------------------------------------------------------------
resource "aws_instance" "k3s" {
  count = var.instance_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.iam_instance_profile

  associate_public_ip_address = var.associate_public_ip
  monitoring                  = var.enable_monitoring

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-ebs-${count.index}-${var.name_suffix}"
    })
  }

  user_data = var.user_data

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-k3s-${count.index}-${var.name_suffix}"
    Role      = count.index == 0 ? "server" : "agent"
    NodeIndex = count.index
    AZ        = var.availability_zones[count.index % length(var.availability_zones)]
  })

  lifecycle {
    ignore_changes = [
      user_data, # Ignore changes to cloud-init after initial boot
    ]
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "instance_ids" {
  value = aws_instance.k3s[*].id
}

output "instance_private_ips" {
  value = aws_instance.k3s[*].private_ip
}

output "instance_public_ips" {
  value = aws_instance.k3s[*].public_ip
}

output "instance_names" {
  value = aws_instance.k3s[*].tags.Name
}

output "server_instance_id" {
  value = aws_instance.k3s[0].id
}

output "server_private_ip" {
  value = aws_instance.k3s[0].private_ip
}

output "server_public_ip" {
  value = var.associate_public_ip ? aws_instance.k3s[0].public_ip : null
}
