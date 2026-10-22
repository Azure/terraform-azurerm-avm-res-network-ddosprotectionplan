mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      object_id                = "00000000-0000-0000-0000-000000000003"
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
      id     = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
      output = {}
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

override_resource {
  target = azapi_resource.resource_group
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test"
  }
}

override_resource {
  target = azapi_resource.public_ip
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-test"
    output = {
      properties = {
        ddosSettings = {
          protectionMode = "Enabled"
          ddosProtectionPlan = {
            id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
          }
        }
      }
    }
  }
}

variables {
  enable_telemetry = false
}

run "public_ip_association" {
  command = apply

  module {
    source = "./examples/complete"
  }

  assert {
    condition = (
      azapi_resource.public_ip.body.sku.name == "Standard" &&
      azapi_resource.public_ip.body.sku.tier == "Regional" &&
      azapi_resource.public_ip.body.properties.publicIPAddressVersion == "IPv4" &&
      azapi_resource.public_ip.body.properties.publicIPAllocationMethod == "Static" &&
      toset(azapi_resource.public_ip.body.zones) == toset(["1", "2", "3"])
    )
    error_message = "The example must create a zone-redundant static IPv4 public IP with regional Standard SKU."
  }

  assert {
    condition = (
      azapi_resource.public_ip.parent_id == azapi_resource.resource_group.id &&
      azapi_resource.public_ip.location == var.ddos_plan_location &&
      azapi_resource.public_ip.body.properties.ddosSettings.protectionMode == "Enabled" &&
      azapi_resource.public_ip.body.properties.ddosSettings.ddosProtectionPlan.id == module.ddosprotectionplan.resource_id &&
      azapi_resource.public_ip.type == "Microsoft.Network/publicIPAddresses@2024-05-01"
    )
    error_message = "The public IP must directly reference the example's plan, rather than inherit VNet protection."
  }

  assert {
    condition     = output.public_ip_resource_id == azapi_resource.public_ip.id && output.public_ip_ddos_protection_plan_id == module.ddosprotectionplan.resource_id
    error_message = "The example must expose the public IP ID and the plan association returned by Azure."
  }

  assert {
    condition = (
      output.resource.id == module.ddosprotectionplan.resource_id &&
      length(output.resource.virtual_network_ids) == 1 &&
      output.resource.virtual_network_ids[0] == azapi_resource.virtual_network.id
    )
    error_message = "The example must output its caller-owned VNet association immediately, without waiting for the plan's read-only back-reference to refresh."
  }
}

run "public_ip_controls" {
  command = apply

  module {
    source = "./examples/complete"
  }

  variables {
    resource_types = {
      network_public_ip_addresses = "Microsoft.Network/publicIPAddresses@2024-07-01"
    }
    retry = {
      error_message_regex  = ["RetryableError"]
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
      network_public_ip_addresses = ["properties.idleTimeoutInMinutes"]
    }
  }

  assert {
    condition = (
      azapi_resource.public_ip.type == var.resource_types.network_public_ip_addresses &&
      azapi_resource.public_ip.retry.interval_seconds == 15 &&
      azapi_resource.public_ip.retry.max_interval_seconds == 60 &&
      azapi_resource.public_ip.retry.error_message_regex[0] == "RetryableError" &&
      azapi_resource.public_ip.timeouts.create == "40m" &&
      azapi_resource.public_ip.timeouts.read == "10m" &&
      azapi_resource.public_ip.timeouts.update == "40m" &&
      azapi_resource.public_ip.timeouts.delete == "40m"
    )
    error_message = "The public IP must honor the API override and shared retry/timeout controls."
  }
}

run "unexpected_public_ip_association" {
  command   = apply
  state_key = "unexpected_association"

  module {
    source = "./examples/complete"
  }

  override_resource {
    target = azapi_resource.public_ip
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-test"
      output = {
        properties = {
          ddosSettings = {
            protectionMode = "Enabled"
            ddosProtectionPlan = {
              id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/wrong-plan"
            }
          }
        }
      }
    }
  }

  expect_failures = [azapi_resource.public_ip]
}
