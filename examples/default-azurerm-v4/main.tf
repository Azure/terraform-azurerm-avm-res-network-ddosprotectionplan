terraform {
  required_version = ">= 1.0.0"

  required_providers {
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  location         = var.rg_location
  name             = module.naming.resource_group.name_unique
  enable_telemetry = var.enable_telemetry
}

# This is the module call
module "ddosprotectionplan" {
  source = "../../"

  location  = var.ddos_plan_location
  name      = module.naming.network_ddos_protection_plan.name_unique
  parent_id = module.resource_group.resource_id
  # source             = "Azure/avm-<res/ptn>-<name>/azurerm"
  enable_telemetry = var.enable_telemetry
}
