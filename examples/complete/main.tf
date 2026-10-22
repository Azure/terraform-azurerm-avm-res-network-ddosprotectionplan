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
  lock = {
    kind = "CanNotDelete"
  }
  role_assignments = {
    reader = {
      principal_id               = data.azapi_client_config.this.object_id
      role_definition_id_or_name = "Reader"
    }
  }
  tags = {
    environment = "example"
  }
}

resource "azapi_resource" "virtual_network" {
  location  = var.ddos_plan_location
  name      = module.naming.virtual_network.name_unique
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.network_virtual_networks
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
      enableDdosProtection = true
      ddosProtectionPlan = {
        id = module.ddosprotectionplan.resource_id
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_virtual_networks) > 0 ? var.ignore_body_changes.network_virtual_networks : null
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

resource "azapi_resource" "public_ip" {
  location  = var.ddos_plan_location
  name      = module.naming.public_ip.name_unique
  parent_id = azapi_resource.resource_group.id
  type      = var.resource_types.network_public_ip_addresses
  body = {
    zones = ["1", "2", "3"]
    sku = {
      name = "Standard"
      tier = "Regional"
    }
    properties = {
      publicIPAddressVersion   = "IPv4"
      publicIPAllocationMethod = "Static"
      ddosSettings = {
        protectionMode = "Enabled"
        ddosProtectionPlan = {
          id = module.ddosprotectionplan.resource_id
        }
      }
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_public_ip_addresses) > 0 ? var.ignore_body_changes.network_public_ip_addresses : null
  response_export_values = ["properties.ddosSettings"]
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

  lifecycle {
    postcondition {
      condition = try(
        self.output.properties.ddosSettings.protectionMode == "Enabled" &&
        lower(self.output.properties.ddosSettings.ddosProtectionPlan.id) == lower(module.ddosprotectionplan.resource_id),
        false
      )
      error_message = "The public IP must report Enabled DDoS protection with the example's DDoS protection plan ID."
    }
  }
}
