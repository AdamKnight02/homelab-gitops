# =============================================================================
# Alibaba Cloud Monitoring Bootstrap Module — Main Resources
# =============================================================================

# ---------------------------------------------------------------------------
# CloudMonitor Alarm Rule (optional)
# ---------------------------------------------------------------------------
resource "alicloud_cms_alarm" "cpu" {
  count = var.enable_cloudmonitor ? 1 : 0

  name    = "${var.name}-cpu-alarm"
  project = "acs_ecs_dashboard"
  metric  = "CPUUtilization"
  period  = 300

  metric_dimensions = jsonencode({
    instanceId = "*" # Will be replaced with actual instance IDs
  })

  escalations_critical {
    comparison_operator = ">"
    threshold           = "90"
    statistics          = "Average"
  }

  contact_groups = ["default"]
}

# ---------------------------------------------------------------------------
# Prometheus Helm Release (via Kubernetes provider)
# ---------------------------------------------------------------------------
# Note: This requires the Kubernetes provider to be configured
# For now, we output the Helm values for manual deployment

locals {
  prometheus_values = {
    server = {
      retention = "${var.prometheus_retention_days}d"
      persistentVolume = {
        size = "10Gi"
      }
    }
    alertmanager = {
      enabled = true
    }
    pushgateway = {
      enabled = false
    }
  }

  grafana_values = {
    adminPassword = var.grafana_admin_password != "" ? var.grafana_admin_password : "admin"
    persistence = {
      enabled = true
      size    = "5Gi"
    }
  }
}

# ---------------------------------------------------------------------------
# Local File for Helm Values (for debugging)
# ---------------------------------------------------------------------------
resource "local_file" "prometheus_values" {
  count = var.enable_prometheus ? 1 : 0

  content  = yamlencode(local.prometheus_values)
  filename = "${path.module}/.debug/prometheus-values.yaml"
}

resource "local_file" "grafana_values" {
  count = var.enable_grafana ? 1 : 0

  content  = yamlencode(local.grafana_values)
  filename = "${path.module}/.debug/grafana-values.yaml"
}
