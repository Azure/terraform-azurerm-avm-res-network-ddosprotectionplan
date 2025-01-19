variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "rg_location" {
  type        = string
  default     = "uksouth"
  description = <<DESCRIPTION
This variable defines the Azure region where the resource group will be created.
The default value is "uksouth".
DESCRIPTION
}

variable "ddos_plan_location" {
  type        = string
  default     = "uksouth"
  description = <<DESCRIPTION
This variable defines the Azure region where the DDOS protection plan will be created.
The default value is "uksouth".
DESCRIPTION
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = var.rg_location
  name     = module.naming.resource_group.name_unique
}

# This is the module call
module "ddosprotectionplan" {
  source = "../../"
  # source             = "Azure/avm-<res/ptn>-<name>/azurerm"
  enable_telemetry    = var.enable_telemetry
  resource_group_name = azurerm_resource_group.this.name
  name                = module.naming.network_ddos_protection_plan.name_unique
  location            = var.ddos_plan_location
}

output "resource" {
  value       = module.ddosprotectionplan.resource
  description = "The ddos protection plan resource."
}
