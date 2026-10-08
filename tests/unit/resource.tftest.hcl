mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000001"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

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
  tags = {
    purpose = "unit-test"
  }
}

run "resource_output_is_a_six_field_projection" {
  command = apply

  assert {
    condition     = keys(output.resource) == ["id", "location", "name", "parent_id", "tags", "type"]
    error_message = "The compatibility output must not expose body or virtual network back-references."
  }
  assert {
    condition     = output.resource.name == "ddos-test" && output.resource.location == "eastus" && output.resource.tags.purpose == "unit-test" && output.resource.parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
    error_message = "The projection must retain the consumer's name, location, tags and resource group scope."
  }
  assert {
    condition     = output.resource.id == output.resource_id && output.name == output.resource.name
    error_message = "Discrete outputs must agree with the compatibility projection."
  }
}

run "read_only_lock_preserves_legacy_notes" {
  command = apply

  variables {
    lock = {
      kind = "ReadOnly"
    }
  }
  assert {
    condition     = azapi_resource.lock[0].name == "lock-ReadOnly" && azapi_resource.lock[0].body.properties.level == "ReadOnly" && azapi_resource.lock[0].body.properties.notes == "Cannot delete or modify the resource or its child resources."
    error_message = "The lock name, level and notes must match the pre-migration ReadOnly contract."
  }
  assert {
    condition     = contains(azapi_resource.this.retry.error_message_regex, "ScopeLocked") && contains(azapi_resource.lock[0].retry.error_message_regex, "ScopeLocked")
    error_message = "The default retry must cover eventual consistency after scope lock removal."
  }
}
