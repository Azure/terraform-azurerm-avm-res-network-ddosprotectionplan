mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000001"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        }]
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    }
  }
}

# Only plan runs use this alias. Both endpoints are deliberately unreachable
# loopback addresses, so a provider regression cannot contact Azure.
provider "azapi" {
  alias                      = "offline"
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  tenant_id                  = "00000000-0000-0000-0000-000000000001"
  client_id                  = "00000000-0000-0000-0000-000000000002"
  client_secret              = "not-a-real-secret"
  use_cli                    = false
  use_msi                    = false
  use_oidc                   = false
  use_aks_workload_identity  = false
  skip_provider_registration = true
  enable_preflight           = false
  ignore_no_op_changes       = false
  disable_instance_discovery = true
  environment                = "public"
  endpoint = [{
    active_directory_authority_host = "https://127.0.0.1:1/"
    resource_manager_endpoint       = "https://127.0.0.1:1/"
    resource_manager_audience       = "https://127.0.0.1:1/"
  }]
}

override_data {
  target = data.azapi_client_config.current
  values = {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    tenant_id       = "00000000-0000-0000-0000-000000000001"
  }
}

override_data {
  target = module.interfaces.data.azapi_resource_list.role_definitions[0]
  values = {
    output = {
      results = [{
        id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        role_name = "Reader"
      }]
    }
  }
}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
  }
}

variables {
  enable_telemetry    = false
  location            = "eastus"
  name                = "ddos-test"
  resource_group_name = "rg-test"
  lock = {
    kind = "CanNotDelete"
  }
  role_assignments = {
    reader = {
      name                       = "11111111-1111-4111-8111-111111111111"
      principal_id               = "22222222-2222-4222-8222-222222222222"
      role_definition_id_or_name = "Reader"
    }
  }
}

run "adopted_guid_baseline" {
  command = apply

  assert {
    condition     = azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "The existing GUID must be retained in state."
  }
  assert {
    condition     = azapi_resource.lock[0].body.properties.notes == "Cannot delete the resource or its child resources."
    error_message = "The migration must preserve the legacy CanNotDelete notes."
  }
}

run "unchanged_assignment_keeps_adopted_guid" {
  command = apply

  variables {
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "The utility's newly generated GUID must not replace an adopted assignment."
  }
}

run "principal_edit_under_lock_is_rejected_before_apply" {
  command = plan

  variables {
    role_assignments = {
      reader = {
        principal_id               = "33333333-3333-4333-8333-333333333333"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["reader"]]
}

run "role_edit_without_lock_is_also_rejected" {
  command = plan

  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["reader"]]
}

run "delegated_identity_edit_is_rejected" {
  command = plan

  variables {
    role_assignments = {
      reader = {
        principal_id                           = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name             = "Reader"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["reader"]]
}

run "condition_added_without_replacing_assignment" {
  command = apply

  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
        condition                  = "(!(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'}))"
        condition_version          = "2.0"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.condition == "(!(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'}))" && azapi_resource.role_assignments["reader"].body.properties.conditionVersion == "2.0"
    error_message = "The condition and version must reach the request together."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "Mutable condition changes must retain the adopted assignment GUID."
  }
}

run "real_provider_plans_an_explicit_condition_clear" {
  command = plan
  providers = {
    azapi = azapi.offline
  }
  plan_options {
    refresh = false
  }
  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
        condition                  = null
        condition_version          = null
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.condition == "" && azapi_resource.role_assignments["reader"].body.properties.conditionVersion == "" && azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "AzAPI must plan an explicit condition clear without changing the adopted GUID."
  }
}

run "condition_removed_with_explicit_null" {
  command = apply

  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
        condition                  = null
        condition_version          = null
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.condition == "" && azapi_resource.role_assignments["reader"].body.properties.conditionVersion == ""
    error_message = "Null must emit an explicit condition clear, not a null stripped by ignore_null_property."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].ignore_null_property && azapi_resource.role_assignments["reader"].body.properties.principalType == null
    error_message = "Clearing conditions must not reintroduce the derived principalType perpetual diff."
  }
}

run "condition_omitted_is_also_explicitly_cleared" {
  command = apply

  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.condition == "" && azapi_resource.role_assignments["reader"].body.properties.conditionVersion == ""
    error_message = "Omitting the condition must have the same clear semantics as explicit null."
  }
}

run "empty_condition_clears_both_fields" {
  command = apply

  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
        condition                  = ""
        condition_version          = "2.0"
      }

    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.condition == "" && azapi_resource.role_assignments["reader"].body.properties.conditionVersion == ""
    error_message = "An empty condition must clear the syntax version too."
  }
}

run "real_provider_keeps_the_adopted_guid" {
  command = plan
  providers = {
    azapi = azapi.offline
  }
  plan_options {
    refresh = false
  }
  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "Real AzAPI plan modifiers must preserve the adopted GUID too."
  }
}

run "real_provider_rejects_principal_only_edit" {
  command = plan
  providers = {
    azapi = azapi.offline
  }
  plan_options {
    refresh = false
  }
  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "33333333-3333-4333-8333-333333333333"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["reader"]]
}

run "real_provider_rejects_role_only_edit" {
  command = plan
  providers = {
    azapi = azapi.offline
  }
  plan_options {
    refresh = false
  }
  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["reader"]]
}

run "real_provider_rejects_delegated_identity_edit" {
  command = plan
  providers = {
    azapi = azapi.offline
  }
  plan_options {
    refresh = false
  }
  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id                           = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name             = "Reader"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["reader"]]
}

run "real_provider_rejects_immutable_and_mutable_edit_together" {
  command = plan
  providers = {
    azapi = azapi.offline
  }
  plan_options {
    refresh = false
  }
  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "33333333-3333-4333-8333-333333333333"
        role_definition_id_or_name = "Reader"
        description                = "An immutable edit must not bypass the guard during a mutable update."
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["reader"]]
}

run "unlock_before_deleting_assignment" {
  command = apply
  variables {
    lock = null
  }
  assert {
    condition     = length(azapi_resource.lock) == 0 && length(azapi_resource.role_assignments) == 1
    error_message = "Unlocking must keep the old assignment until a separate apply deletes it."
  }
}

run "remove_old_assignment_before_recreating" {
  command = apply
  variables {
    lock             = null
    role_assignments = {}
  }
  assert {
    condition     = length(azapi_resource.role_assignments) == 0
    error_message = "The old assignment must be removed before reusing its key."
  }
}

run "recreate_with_new_principal_and_fresh_guid" {
  command = apply
  variables {
    lock = null
    role_assignments = {
      reader = {
        principal_id               = "33333333-3333-4333-8333-333333333333"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name != "11111111-1111-4111-8111-111111111111" && azapi_resource.role_assignments["reader"].body.properties.principalId == "33333333-3333-4333-8333-333333333333"
    error_message = "Staged recreation must allow the new principal with a fresh assignment GUID."
  }
}

run "relock_after_recreating_assignment" {
  command = apply
  variables {
    role_assignments = {
      reader = {
        principal_id               = "33333333-3333-4333-8333-333333333333"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  assert {
    condition     = length(azapi_resource.lock) == 1 && azapi_resource.role_assignments["reader"].body.properties.principalId == "33333333-3333-4333-8333-333333333333"
    error_message = "Restoring the lock must preserve the replacement assignment."
  }
}
