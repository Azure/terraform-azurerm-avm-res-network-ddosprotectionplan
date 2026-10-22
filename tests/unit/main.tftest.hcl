mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000001"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001"
      tenant_id                = "00000000-0000-0000-0000-000000000002"
    }
  }

  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000001/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        }]
      }
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
      output = {
        properties = {
          virtualNetworks = [{
            id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
          }]
        }
      }
    }
  }
}

mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "00000000-0000-0000-0000-000000000004"
    }
  }
}

mock_provider "time" {}

variables {
  location  = "uksouth"
  name      = "ddos-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test"
}

run "default_plan_contract" {
  command = apply

  variables {
    enable_telemetry = null
  }

  assert {
    condition     = output.name == var.name && output.resource_id == azapi_resource.this.id && output.resource.id == output.resource_id
    error_message = "The name, resource_id, and compatibility resource outputs must identify the DDoS protection plan."
  }

  assert {
    condition     = azapi_resource.this.location == var.location && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.type == "Microsoft.Network/ddosProtectionPlans@2024-05-01"
    error_message = "The plan must use the requested location, parent, and default API version."
  }

  assert {
    condition     = jsonencode(azapi_resource.this.body) == jsonencode({ properties = {} })
    error_message = "Read-only virtual network associations must not be written in the plan's request body."
  }

  assert {
    condition     = output.resource.resource_group_name == "rg-test" && output.resource.location == var.location && output.resource.virtual_network_ids == output.virtual_network_ids && length(output.virtual_network_ids) == 1
    error_message = "The compatibility output must retain the released public attributes and export associated virtual network IDs."
  }

  assert {
    condition     = length(azapi_resource.lock) == 0 && length(azapi_resource.role_assignments) == 0 && length(time_sleep.wait_for_resource_destroy) == 0 && length(data.azapi_resource_list.role_definitions) == 0
    error_message = "Locks, role assignments, role lookups, and the lock pause must remain optional."
  }

  assert {
    condition     = length(terraform_data.telemetry) == 1
    error_message = "Telemetry must remain enabled by default."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "combined_interfaces_and_controls" {
  command = apply

  variables {
    enable_telemetry = false
    lock = {
      kind = "CanNotDelete"
    }
    role_assignments = {
      reader = {
        role_definition_id_or_name       = "rEaDeR"
        principal_id                     = "00000000-0000-0000-0000-000000000003"
        skip_service_principal_aad_check = true
      }
    }
    tags = {
      environment = "test"
    }
    resource_types = {
      network_ddos_protection_plans = "Microsoft.Network/ddosProtectionPlans@2023-11-01"
    }
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 15
      max_interval_seconds = 60
    }
    timeouts = {
      create = "40m"
      read   = "10m"
      update = "40m"
      delete = "40m"
    }
    ignore_body_changes = {
      network_ddos_protection_plans  = ["tags"]
      authorization_locks            = ["properties.notes"]
      authorization_role_assignments = ["properties.description"]
    }
  }

  assert {
    condition     = azapi_resource.lock[0].name == "lock-CanNotDelete" && azapi_resource.lock[0].body.properties.level == "CanNotDelete" && azapi_resource.lock[0].body.properties.notes == "Cannot delete the resource or its child resources." && azapi_resource.lock[0].parent_id == output.resource_id
    error_message = "The lock must preserve the released default name, notes, level, and scope."
  }

  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.principalId == var.role_assignments.reader.principal_id && azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal" && endswith(azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId, "/acdd72a7-3385-48ef-bd42-f606fba81ae7") && azapi_resource.role_assignments["reader"].parent_id == output.resource_id
    error_message = "Role names must resolve case-insensitively, and skip_service_principal_aad_check must map to the ARM principalType."
  }

  assert {
    condition     = data.azapi_resource_list.role_definitions[0].parent_id == var.parent_id
    error_message = "Role lookup must use the input parent scope, not an apply-time read of the DDoS plan."
  }

  assert {
    condition     = output.resource.tags == var.tags && azapi_resource.this.type == var.resource_types.network_ddos_protection_plans
    error_message = "Tags and resource-type overrides must pass through."
  }

  assert {
    condition = alltrue([
      for resource in [azapi_resource.this, azapi_resource.lock[0], azapi_resource.role_assignments["reader"]] :
      resource.retry.interval_seconds == 15 && resource.retry.max_interval_seconds == 60 &&
      resource.retry.error_message_regex[0] == "ScopeLocked" &&
      resource.timeouts.create == "40m" && resource.timeouts.read == "10m" &&
      resource.timeouts.update == "40m" && resource.timeouts.delete == "40m"
    ])
    error_message = "Retry and timeout controls must be applied to the primary resource, lock, and assignments."
  }

  assert {
    condition     = length(time_sleep.wait_for_resource_destroy) == 1 && time_sleep.wait_for_resource_destroy[0].destroy_duration == "30s" && time_sleep.wait_for_resource_destroy[0].triggers.resource_id == output.resource_id
    error_message = "Lock removal must include the scoped propagation pause."
  }

  assert {
    condition     = length(terraform_data.telemetry) == 0
    error_message = "Telemetry must be absent when disabled."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "explicit_assignment_and_lock" {
  command = apply

  variables {
    enable_telemetry = false
    lock = {
      kind  = "ReadOnly"
      name  = "hold"
      notes = "Custom lock notes."
    }
    role_assignments = {
      explicit = {
        name                                   = "00000000-0000-0000-0000-000000000005"
        principal_id                           = "00000000-0000-0000-0000-000000000003"
        role_definition_id_or_name             = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_type                         = "Group"
        skip_service_principal_aad_check       = true
        description                            = "Explicit assignment"
        condition                              = "(!(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'}))"
        condition_version                      = "2.0"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/identity"
      }
    }
    resource_types = {
      authorization_locks            = "Microsoft.Authorization/locks@2016-09-01"
      authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["explicit"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000001/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" && length(data.azapi_resource_list.role_definitions) == 0
    error_message = "Tenant-level role IDs must gain the subscription scope without performing a role-name lookup."
  }

  assert {
    condition     = azapi_resource.role_assignments["explicit"].name == var.role_assignments.explicit.name && azapi_resource.role_assignments["explicit"].body.properties.principalType == "Group" && azapi_resource.role_assignments["explicit"].body.properties.description == "Explicit assignment" && azapi_resource.role_assignments["explicit"].body.properties.conditionVersion == "2.0" && azapi_resource.role_assignments["explicit"].body.properties.condition == var.role_assignments.explicit.condition && azapi_resource.role_assignments["explicit"].body.properties.delegatedManagedIdentityResourceId == var.role_assignments.explicit.delegated_managed_identity_resource_id
    error_message = "Explicit names, principal type, conditions, descriptions, and delegated identity must map to the correct ARM property names."
  }

  assert {
    condition     = azapi_resource.lock[0].name == "hold" && azapi_resource.lock[0].body.properties.notes == "Custom lock notes." && azapi_resource.lock[0].type == var.resource_types.authorization_locks && azapi_resource.role_assignments["explicit"].type == var.resource_types.authorization_role_assignments
    error_message = "Custom lock attributes and extension-resource API overrides must be honored."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "readonly_default_notes" {
  command = apply

  variables {
    enable_telemetry = false
    lock = {
      kind = "ReadOnly"
    }
  }

  assert {
    condition     = azapi_resource.lock[0].body.properties.notes == "Cannot delete or modify the resource or its child resources."
    error_message = "ReadOnly locks must retain the released default notes."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "explicit_empty_notes_and_absent_associations" {
  command   = apply
  state_key = "empty_associations"

  variables {
    enable_telemetry = false
    lock = {
      kind  = "CanNotDelete"
      notes = ""
    }
  }

  override_resource {
    target = azapi_resource.this
    values = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
      output = {}
    }
  }

  assert {
    condition     = azapi_resource.lock[0].body.properties.notes == ""
    error_message = "Explicit empty lock notes must not be replaced with the default wording."
  }

  assert {
    condition     = length(output.virtual_network_ids) == 0 && length(output.resource.virtual_network_ids) == 0
    error_message = "Azure may omit virtualNetworks when there are no associations; both output surfaces must return an empty collection."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_lock_kind" {
  command = plan

  variables {
    enable_telemetry = false
    lock = {
      kind = "Invalid"
    }
  }

  expect_failures = [var.lock]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_parent_id" {
  command = plan

  variables {
    enable_telemetry = false
    parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000001"
  }

  expect_failures = [var.parent_id]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_delegated_identity_id" {
  command = plan

  variables {
    enable_telemetry = false
    role_assignments = {
      invalid = {
        principal_id                           = "00000000-0000-0000-0000-000000000003"
        role_definition_id_or_name             = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        delegated_managed_identity_resource_id = "not-an-arm-id"
      }
    }
  }

  expect_failures = [var.role_assignments]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "unknown_role_name" {
  command = plan

  variables {
    enable_telemetry = false
    role_assignments = {
      invalid = {
        principal_id               = "00000000-0000-0000-0000-000000000003"
        role_definition_id_or_name = "Missing Role"
      }
    }
  }

  expect_failures = [azapi_resource.role_assignments["invalid"]]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
