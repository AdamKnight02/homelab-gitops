# Shared Naming Module
# Generates standardized resource names following the pattern:
# <prefix>-<customer>-<environment>-<component>-<instance>

locals {
  prefix      = lower(var.cloud_prefix)
  customer    = lower(var.customer)
  environment = lower(var.environment_abbreviation)
  component   = lower(var.component)
  instance    = lower(var.instance)

  base = "${local.prefix}-${local.customer}-${local.environment}"

  resource_group_name     = "${local.base}-rg-${local.component}-${local.instance}"
  vnet_name               = "${local.base}-vnet-${local.component}-${local.instance}"
  subnet_names            = { for k in ["pki", "gateway", "db", "container"] : k => "${local.base}-snet-${k}-${local.instance}" }
  nsg_names               = { for k in ["pki", "gateway", "db", "container"] : k => "${local.base}-nsg-${k}-${local.instance}" }
  keyvault_name           = "${local.base}-kv-${local.component}-${local.instance}"
  storage_account_name    = replace("${local.prefix}${local.customer}${local.environment}st${local.component}${local.instance}", "-", "")
  vm_name                 = "${local.base}-vm-${local.component}-${local.instance}"
  nic_name                = "${local.base}-nic-${local.component}-${local.instance}"
  disk_name               = "${local.base}-disk-${local.component}-${local.instance}"
  gateway_name            = "${local.base}-gw-${local.component}-${local.instance}"
  public_ip_name          = "${local.base}-pip-${local.component}-${local.instance}"
  postgresql_server_name  = "${local.base}-psql-${local.component}-${local.instance}"
  identity_names          = { for k in ["pki", "gateway", "automation"] : k => "${local.base}-id-${k}-${local.instance}" }
  scep_name               = "${local.base}-scep-${local.component}-${local.instance}"
  acme_name               = "${local.base}-acme-${local.component}-${local.instance}"
  automation_account_name = "${local.base}-aa-${local.component}-${local.instance}"
  log_analytics_name      = "${local.base}-law-${local.component}-${local.instance}"
}
