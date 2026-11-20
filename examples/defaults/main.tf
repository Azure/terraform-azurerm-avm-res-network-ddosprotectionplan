provider "azapi" {}

data "azapi_client_config" "this" {}

module "naming" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"
}

resource "azapi_resource" "resource_group" {
  location               = var.rg_location
  name                   = module.naming.resource_group.name_unique
  parent_id              = data.azapi_client_config.this.subscription_resource_id
  type                   = var.resource_types.resources_resource_groups
  ignore_body_changes    = length(var.ignore_body_changes.resources_resource_groups) > 0 ? var.ignore_body_changes.resources_resource_groups : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

module "ddosprotectionplan" {
  source = "../../"

  location         = var.ddos_plan_location
  name             = module.naming.network_ddos_protection_plan.name_unique
  parent_id        = azapi_resource.resource_group.id
  enable_telemetry = var.enable_telemetry
}
