resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_ddos_protection_plans
  body = {
    properties = {}
  }
  create_headers      = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers      = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_body_changes = length(var.ignore_body_changes.network_ddos_protection_plans) > 0 ? var.ignore_body_changes.network_ddos_protection_plans : null
  read_headers        = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = {
    id   = "id"
    name = "name"
    type = "type"
  }
  retry          = var.retry
  tags           = var.tags
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  timeouts {
    create = var.timeouts.network_ddos_protection_plans.create
    delete = var.timeouts.network_ddos_protection_plans.delete
    read   = var.timeouts.network_ddos_protection_plans.read
    update = var.timeouts.network_ddos_protection_plans.update
  }
}

module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  enable_telemetry                          = var.enable_telemetry
  lock                                      = var.lock
  role_assignment_definition_lookup_enabled = true
  role_assignment_definition_scope          = azapi_resource.this.id
  role_assignments                          = var.role_assignments
}

resource "azapi_resource" "role_assignments" {
  for_each = module.avm_interfaces.role_assignments_azapi

  name           = each.value.name
  parent_id      = azapi_resource.this.id
  type           = each.value.type
  body           = each.value.body
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = {
    id               = "id"
    name             = "name"
    principalId      = "properties.principalId"
    principalType    = "properties.principalType"
    roleDefinitionId = "properties.roleDefinitionId"
    scope            = "properties.scope"
    type             = "type"
  }
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name           = coalesce(var.lock.name, "lock-${var.lock.kind}")
  parent_id      = azapi_resource.this.id
  type           = module.avm_interfaces.lock_azapi.type
  body           = module.avm_interfaces.lock_azapi.body
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  depends_on = [time_sleep.wait_for_resource_destroy]
}

resource "time_sleep" "wait_for_resource_destroy" {
  destroy_duration = "20s"

  depends_on = [azapi_resource.this]
}
