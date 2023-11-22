# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  name     = module.naming.resource_group.name_unique
  location = var.rg_location
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

# This is the module call
module "DDOSPROTECTIONPLAN" {
  source = "../../"
  # source             = "Azure/avm-<res/ptn>-<name>/azurerm"
  enable_telemetry    = var.enable_telemetry
  resource_group_name = azurerm_resource_group.this.name
  name                = module.naming.ddos_plan.name_unique
  location            = var.ddos_plan_location
  diagnostic_settings = {
    to_la = {
      name                  = "to-la"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
    }
  }
}
