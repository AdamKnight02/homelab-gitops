# =============================================================================
# Alibaba Cloud Security Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# Security Group
# Default: deny all inbound. SSH only if allow_ssh_cidr is specified.
# ---------------------------------------------------------------------------
resource "alicloud_security_group" "main" {
  security_group_name = "${var.name}-sg"
  description         = "Security group for PKI platform"
  vpc_id              = var.vpc_id
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Security Group Rules — SSH
# ---------------------------------------------------------------------------
resource "alicloud_security_group_rule" "ssh" {
  for_each = toset(var.allow_ssh_cidr)

  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = each.value
  description       = "SSH from ${each.value}"
}

# ---------------------------------------------------------------------------
# Security Group Rules — Kubernetes API
# ---------------------------------------------------------------------------
resource "alicloud_security_group_rule" "k8s_api" {
  for_each = toset(var.allow_k8s_api_cidr)

  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "6443/6443"
  priority          = 2
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = each.value
  description       = "K8s API from ${each.value}"
}

# ---------------------------------------------------------------------------
# Security Group Rules — HTTP
# ---------------------------------------------------------------------------
resource "alicloud_security_group_rule" "http" {
  for_each = toset(var.allow_http_cidr)

  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 3
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = each.value
  description       = "HTTP from ${each.value}"
}

# ---------------------------------------------------------------------------
# Security Group Rules — HTTPS
# ---------------------------------------------------------------------------
resource "alicloud_security_group_rule" "https" {
  for_each = toset(var.allow_https_cidr)

  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "443/443"
  priority          = 4
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = each.value
  description       = "HTTPS from ${each.value}"
}

# ---------------------------------------------------------------------------
# Security Group Rules — Internal Cluster Communication
# Allow all traffic within the security group (for K3s cluster)
# ---------------------------------------------------------------------------
resource "alicloud_security_group_rule" "internal" {
  type                     = "ingress"
  ip_protocol              = "all"
  nic_type                 = "intranet"
  policy                   = "accept"
  port_range               = "-1/-1"
  priority                 = 5
  security_group_id        = alicloud_security_group.main.id
  source_security_group_id = alicloud_security_group.main.id
  description              = "Allow all internal cluster traffic"
}

# ---------------------------------------------------------------------------
# Security Group Rules — Egress (allow all outbound)
# ---------------------------------------------------------------------------
resource "alicloud_security_group_rule" "egress" {
  type              = "egress"
  ip_protocol       = "all"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "-1/-1"
  priority          = 1
  security_group_id = alicloud_security_group.main.id
  cidr_ip           = "0.0.0.0/0"
  description       = "Allow all outbound traffic"
}
