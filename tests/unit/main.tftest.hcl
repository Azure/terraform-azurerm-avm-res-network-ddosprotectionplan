mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000001"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001"
      tenant_id                = "00000000-0000-0000-0000-000000000002"
    }
  }
}

mock_provider "azurerm" {
  mock_resource "azurerm_network_ddos_protection_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
    }
  }
}

variables {
  location            = "uksouth"
  name                = "ddos-test"
  resource_group_name = "rg-test"
}

run "default_plan_contract" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm


  }

  variables {
    # Use the non-nullable default instead of an inherited TF_VAR override.
    enable_telemetry = null
  }

  assert {
    condition     = output.name == var.name && output.resource_id == azurerm_network_ddos_protection_plan.this.id && output.resource.id == output.resource_id
    error_message = "The existing name, resource_id, and resource outputs must identify the DDoS protection plan."
  }

  assert {
    condition     = azurerm_network_ddos_protection_plan.this.location == var.location && azurerm_network_ddos_protection_plan.this.resource_group_name == var.resource_group_name
    error_message = "The plan must retain the requested location and resource group."
  }

  assert {
    condition     = length(azurerm_management_lock.this) == 0 && length(azurerm_role_assignment.this) == 0
    error_message = "Locks and role assignments must remain optional."
  }

  assert {
    condition     = length(terraform_data.telemetry) == 1
    error_message = "Telemetry must remain enabled by default."
  }
}

run "optional_resources_and_opt_out" {
  command = apply

  providers = {
    azapi   = azapi
    azurerm = azurerm


  }

  variables {
    enable_telemetry = false
    lock = {
      kind = "CanNotDelete"
      name = "hold"
    }
    role_assignments = {
      reader = {
        principal_id               = "00000000-0000-0000-0000-000000000003"
        role_definition_id_or_name = "Reader"
      }
    }
    tags = {
      environment = "test"
    }
  }

  assert {
    condition     = azurerm_management_lock.this[0].name == "hold" && azurerm_management_lock.this[0].lock_level == "CanNotDelete" && azurerm_management_lock.this[0].scope == output.resource_id
    error_message = "The lock must retain its name, level, and DDoS plan scope."
  }

  assert {
    condition     = azurerm_role_assignment.this["reader"].principal_id == var.role_assignments.reader.principal_id && azurerm_role_assignment.this["reader"].role_definition_name == "Reader" && azurerm_role_assignment.this["reader"].scope == output.resource_id
    error_message = "The role assignment must retain its principal, role, and DDoS plan scope."
  }

  assert {
    condition     = output.resource.tags == var.tags
    error_message = "Tags must pass through to the DDoS plan."
  }

  assert {
    condition     = length(terraform_data.telemetry) == 0
    error_message = "Telemetry must be absent when disabled."
  }
}

run "invalid_lock_kind" {
  command = plan

  providers = {
    azapi   = azapi
    azurerm = azurerm


  }

  variables {
    enable_telemetry = false
    lock = {
      kind = "Invalid"
    }
  }

  expect_failures = [var.lock]
}
