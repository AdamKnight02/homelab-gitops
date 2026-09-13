# =============================================================================
# AWS Load Balancer Module
# =============================================================================
# Tier-aware load balancer: NLB for standard/enterprise.
# Economy: no load balancer (NodePort or direct access).
# Standard: NLB for K3s API and ingress.
# Enterprise: NLB (ALB optional via variable).
# =============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "name_prefix" { type = string }
variable "name_suffix" { type = string }
variable "service_tier" { type = string }
variable "load_balancer_type" { type = string } # "none", "nlb", "alb"
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "instance_ids" { type = list(string) }
variable "tags" { type = map(string) }

# ---------------------------------------------------------------------------
# Network Load Balancer (Standard+)
# ---------------------------------------------------------------------------
resource "aws_lb" "main" {
  count = var.load_balancer_type != "none" ? 1 : 0

  name               = "${var.name_prefix}-nlb-${var.name_suffix}"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection       = var.service_tier == "enterprise" ? true : false
  enable_cross_zone_load_balancing = var.service_tier == "enterprise" ? true : false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nlb-${var.name_suffix}"
    Tier = var.service_tier
  })
}

# ---------------------------------------------------------------------------
# Target Group — K3s API
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "k3s_api" {
  count = var.load_balancer_type != "none" ? 1 : 0

  name     = "${var.name_prefix}-k3s-api-${var.name_suffix}"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = 6443
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s-api-tg-${var.name_suffix}"
  })
}

resource "aws_lb_target_group_attachment" "k3s_api" {
  count = var.load_balancer_type != "none" ? length(var.instance_ids) : 0

  target_group_arn = aws_lb_target_group.k3s_api[0].arn
  target_id        = var.instance_ids[count.index]
  port             = 6443
}

# ---------------------------------------------------------------------------
# Target Group — HTTP (Ingress)
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "http" {
  count = var.load_balancer_type != "none" ? 1 : 0

  name     = "${var.name_prefix}-http-${var.name_suffix}"
  port     = 30080 # NodePort for ingress HTTP
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "30080"
    path                = "/healthz"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-http-tg-${var.name_suffix}"
  })
}

resource "aws_lb_target_group_attachment" "http" {
  count = var.load_balancer_type != "none" ? length(var.instance_ids) : 0

  target_group_arn = aws_lb_target_group.http[0].arn
  target_id        = var.instance_ids[count.index]
  port             = 30080
}

# ---------------------------------------------------------------------------
# Target Group — HTTPS (Ingress)
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "https" {
  count = var.load_balancer_type != "none" ? 1 : 0

  name     = "${var.name_prefix}-https-${var.name_suffix}"
  port     = 30443 # NodePort for ingress HTTPS
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTPS"
    port                = "30443"
    path                = "/healthz"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-https-tg-${var.name_suffix}"
  })
}

resource "aws_lb_target_group_attachment" "https" {
  count = var.load_balancer_type != "none" ? length(var.instance_ids) : 0

  target_group_arn = aws_lb_target_group.https[0].arn
  target_id        = var.instance_ids[count.index]
  port             = 30443
}

# ---------------------------------------------------------------------------
# Listeners
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "k3s_api" {
  count = var.load_balancer_type != "none" ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s_api[0].arn
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  count = var.load_balancer_type != "none" ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http[0].arn
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  count = var.load_balancer_type != "none" ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https[0].arn
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "lb_arn" {
  value = var.load_balancer_type != "none" ? aws_lb.main[0].arn : null
}

output "lb_dns_name" {
  value = var.load_balancer_type != "none" ? aws_lb.main[0].dns_name : null
}

output "lb_zone_id" {
  value = var.load_balancer_type != "none" ? aws_lb.main[0].zone_id : null
}

output "k3s_api_endpoint" {
  value = var.load_balancer_type != "none" ? "https://${aws_lb.main[0].dns_name}:6443" : null
}
