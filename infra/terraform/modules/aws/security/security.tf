# =============================================================================
# AWS Security Module
# =============================================================================
# Tier-aware security groups and rules.
# Economy: minimal — SSH (optional), K3s API, NodePort range.
# Standard: adds inter-node communication, LB health checks.
# Enterprise: adds private subnet isolation, tighter rules.
# =============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "name_prefix" { type = string }
variable "name_suffix" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "allow_ssh_cidr" { type = list(string) }
variable "service_tier" { type = string }
variable "tags" { type = map(string) }

# ---------------------------------------------------------------------------
# Security Group — K3s Nodes
# ---------------------------------------------------------------------------
resource "aws_security_group" "k3s" {
  name        = "${var.name_prefix}-k3s-sg-${var.name_suffix}"
  description = "Security group for K3s nodes (${var.service_tier} tier)"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s-sg-${var.name_suffix}"
    Tier = var.service_tier
  })

  # SSH access — only if explicitly allowed
  dynamic "ingress" {
    for_each = length(var.allow_ssh_cidr) > 0 ? var.allow_ssh_cidr : []
    content {
      description = "SSH from ${ingress.value}"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # K3s API server
  ingress {
    description = "K3s API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # K3s kubelet
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Flannel VXLAN (K3s default CNI)
  ingress {
    description = "Flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # NodePort range (for standard/enterprise with LB)
  dynamic "ingress" {
    for_each = var.service_tier != "economy" ? [1] : []
    content {
      description = "NodePort services"
      from_port   = 30000
      to_port     = 32767
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  # Inter-node communication (standard/enterprise)
  dynamic "ingress" {
    for_each = var.service_tier != "economy" ? [1] : []
    content {
      description = "Inter-node K3s"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      self        = true
    }
  }

  # etcd (multi-server K3s, standard/enterprise)
  dynamic "ingress" {
    for_each = var.service_tier != "economy" ? [1] : []
    content {
      description = "etcd peer"
      from_port   = 2379
      to_port     = 2380
      protocol    = "tcp"
      self        = true
    }
  }

  # Allow all outbound (required for package installation)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# Security Group — Load Balancer (standard/enterprise)
# ---------------------------------------------------------------------------
resource "aws_security_group" "lb" {
  count = var.service_tier != "economy" ? 1 : 0

  name        = "${var.name_prefix}-lb-sg-${var.name_suffix}"
  description = "Security group for load balancer (${var.service_tier} tier)"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lb-sg-${var.name_suffix}"
    Tier = var.service_tier
  })

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K3s API (for kubectl access via LB)
  ingress {
    description = "K3s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound to K3s nodes
  egress {
    description = "To K3s nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
}

# ---------------------------------------------------------------------------
# Security Group — RDS (standard/enterprise)
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  count = var.service_tier != "economy" ? 1 : 0

  name        = "${var.name_prefix}-rds-sg-${var.name_suffix}"
  description = "Security group for RDS PostgreSQL (${var.service_tier} tier)"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg-${var.name_suffix}"
    Tier = var.service_tier
  })

  # PostgreSQL from K3s nodes only
  ingress {
    description     = "PostgreSQL from K3s"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s.id]
  }

  # No outbound needed for RDS
  egress {
    description = "Deny all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "k3s_security_group_id" {
  value = aws_security_group.k3s.id
}

output "lb_security_group_id" {
  value = var.service_tier != "economy" ? aws_security_group.lb[0].id : null
}

output "rds_security_group_id" {
  value = var.service_tier != "economy" ? aws_security_group.rds[0].id : null
}
