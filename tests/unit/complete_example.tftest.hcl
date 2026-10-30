mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      object_id                = "00000000-0000-0000-0000-000000000003"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "random" {}
mock_provider "time" {}

override_resource {
  target = azapi_resource.resource_group
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test"
  }
}

override_module {
  target = module.ddosprotectionplan
  outputs = {
    resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
    resource = {
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
      virtual_network_ids = []
    }
  }
}

run "vnet_association" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    enable_telemetry = false
  }

  assert {
    condition = (
      azapi_resource.virtual_network.body.properties.enableDdosProtection &&
      azapi_resource.virtual_network.body.properties.ddosProtectionPlan.id == module.ddosprotectionplan.resource_id &&
      azapi_resource.virtual_network.parent_id == azapi_resource.resource_group.id
    )
    error_message = "The complete example must associate its caller-owned VNet with the DDoS plan."
  }

  assert {
    condition = (
      output.resource.id == module.ddosprotectionplan.resource_id &&
      length(output.resource.virtual_network_ids) == 1 &&
      output.resource.virtual_network_ids[0] == azapi_resource.virtual_network.id
    )
    error_message = "The complete example must output its VNet ID immediately rather than the stale plan back-reference."
  }
}
