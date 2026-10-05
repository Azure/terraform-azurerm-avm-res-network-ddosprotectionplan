terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

provider "azapi" {}

# NOTE: the azurerm provider block below is required only when upgrading a
# deployment that was created with a module version which used the azurerm
# provider, so that Terraform can still read the pre-migration state rows while
# the module's `moved` blocks convert them. It can be removed for new
# deployments, and after the upgrade has been applied.
#
# provider "azurerm" {
#   features {}
# }

# Importing the Azure naming module to ensure resources have unique CAF compliant names.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

data "azapi_client_config" "current" {}

# This is required for resource modules
resource "azapi_resource" "this" {
  location  = var.rg_location
  name      = module.naming.resource_group.name_unique
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type      = "Microsoft.Resources/resourceGroups@2025-04-01"
  body = {
    properties = {}
  }
  response_export_values = []
}

# This is the module call
module "ddosprotectionplan" {
  source = "../../"

  location            = var.ddos_plan_location
  name                = module.naming.network_ddos_protection_plan.name_unique
  resource_group_name = azapi_resource.this.name
  # source             = "Azure/avm-<res/ptn>-<name>/azurerm"
  enable_telemetry = var.enable_telemetry
}
