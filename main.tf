# =============================================================================
# Standard AVM interfaces (`avm-tf-interfaces` SKILL.md, RMFR4/RMFR5)
#
# The lock and the role assignments are composed through the shared utility
# module so that their bodies, API versions and role-definition name lookup stay
# in one place. Only the inputs this resource actually supports are passed:
# a DDoS protection plan has no diagnostic settings, no managed identity, no
# private endpoints and no customer-managed key.
# =============================================================================
module "interfaces" {
  source = "Azure/avm-utl-interfaces/azure"
  # `avm-tf-migration` SKILL.md L103 writes this constraint as `~> 0.6`, but the
  # AVM `terraform_module_version` lint rule requires an exact version, and on a
  # two-segment constraint `~> 0.6` would in any case float all the way to 1.0.
  # Pinned to the current registry release; its `lock_azapi` and
  # `role_assignments_azapi` shapes and both ARM types are identical to 0.6.0.
  version = "0.7.0"

  enable_telemetry = var.enable_telemetry
  lock             = local.lock
  # Role definitions given by name are resolved against the subscription that
  # owns the plan - the same scope the pre-migration `azurerm_role_assignment`
  # used for its `role_definition_name` lookup.
  role_assignment_definition_scope = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  role_assignments                 = var.role_assignments
}

# =============================================================================
# DDoS protection plan - `Microsoft.Network/ddosProtectionPlans`
#
# WHY A PLAIN SINGLE WRITER, NOT THE CREATE-ONLY + UPDATE TWO-WRITER SHAPE
#
# Measured against the ARM type registry embedded in azapi 2.13.0 at
# api-version 2025-07-01: `DdosProtectionPlanPropertiesFormat` declares four
# properties - `resourceGuid`, `provisioningState`, `virtualNetworks` and
# `publicIPAddresses` - and every one of them carries the ReadOnly flag. The
# writable body surface of this resource type is therefore EMPTY, and a full
# PUT of `{ "properties": {} }` cannot drop a server-owned value.
#
# The create-only + `azapi_update_resource` shape used elsewhere in the ALZ
# estate exists purely to stop a full PUT clobbering properties the module does
# not model. With nothing writable to clobber it would buy nothing and would
# cost the ability to un-set a property, so it is not used here. This is the
# same reasoning recorded on `azapi_resource.diagnostic_setting` in the vWAN
# pattern module's `modules/firewall`.
#
# `virtualNetworks` is the read-only back-reference Azure populates when a vNet
# points `properties.ddosProtectionPlan.id` at this plan. It is deliberately not
# exported: a plan is shared across subscriptions and state files by design, so
# exporting it would surface every unrelated vNet association as drift here.
#
# FORCENEW PARITY: the pre-migration resource forced replacement on `name`,
# `location` and `resource_group_name`. On `azapi_resource`, `name` and
# `parent_id` are RequiresReplace and `parent_id` carries the resource group, so
# both of those are preserved. `location` is NOT RequiresReplace on
# `azapi_resource`; ARM rejects a cross-region move of an existing plan, so a
# `location` change surfaces as an apply-time API error instead of a plan-time
# replacement. No precondition is added for it because the error is explicit.
# =============================================================================
resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = local.parent_id
  type      = var.resource_types.network_ddos_protection_plans
  # Every property of this type is read-only; see the block comment above.
  body = {
    properties = {}
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_ddos_protection_plans) > 0 ? var.ignore_body_changes.network_ddos_protection_plans : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    # `moved` hands over a state row whose `response_export_values` is null
    # (azapi's `MoveState` builds a default model and the following refresh
    # never populates it). Without this the first plan after an upgrade shows a
    # cosmetic `null -> []` change and a pointless PUT on every existing plan.
    # `response_export_values` is hard-coded here, never consumer-supplied, so
    # ignoring it costs nothing. Remove this if the resource ever needs a real
    # export. Same pattern as the vWAN firewall's `diagnostic_setting`.
    ignore_changes = [response_export_values]
  }
}

# =============================================================================
# Management lock (RMFR5)
# =============================================================================
resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name                   = coalesce(module.interfaces.lock_azapi.name, "lock-${var.lock.kind}")
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_locks
  body                   = module.interfaces.lock_azapi.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    ignore_changes = [response_export_values]
  }
  depends_on = [azapi_resource.role_assignments]
}

# =============================================================================
# Role assignments (RMFR4)
#
# `ignore_changes = [name]` is the migration case named in `avm-tf-migration`
# SKILL.md L109-117. A role assignment's name is a GUID that Azure generated
# when the pre-migration `azurerm_role_assignment` created it, and `moved`
# carries that GUID into the azapi state row. The interfaces module cannot know
# it - `var.role_assignments[*].name` is null unless the caller pins it - so it
# supplies a fresh `random_uuid` instead, and `name` is RequiresReplace on
# `azapi_resource`, which would tear down and recreate every existing role
# assignment on upgrade. Ignoring `name` after creation pins the
# server-assigned GUID and keeps the upgrade free of replacements, without
# making consumers pass anything. The trade-off is that changing `name` on an
# already-created assignment has no effect; it is only honoured at create time.
#
# The utility emits optional nulls. Remove unset principalType because Azure
# derives it, but retain condition nulls to clear them in PUT. A blanket
# ignore_null_property would also suppress condition clearing. Keep the
# delegated-identity key so lifecycle can retain and check its immutable state.
#
# PARITY NOTES, both plan-visible as in-place updates and neither a replacement:
#   * `description` and `principal_type` were accepted by the variable but never
#     forwarded by the pre-migration resource. They are sent now, so a consumer
#     that already set them will see the body converge on first apply.
#   * `skip_service_principal_aad_check` has no ARM body representation - it
#     controlled an azurerm-side retry on AAD replication lag. The azapi `retry`
#     block covers the same failure; the field is kept on the variable for
#     interface compatibility and is ignored.
# =============================================================================
resource "azapi_resource" "role_assignments" {
  for_each = module.interfaces.role_assignments_azapi

  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = merge({
      for key, value in each.value.body.properties : key => value if value != null || key == "delegatedManagedIdentityResourceId"
      }, {
      condition        = each.value.body.properties.condition == "" ? null : each.value.body.properties.condition
      conditionVersion = each.value.body.properties.condition == null || each.value.body.properties.condition == "" ? null : each.value.body.properties.conditionVersion
    })
  }
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_null_property = false
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.delegatedManagedIdentityResourceId",
  ]
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    # Retain immutable state for the check below instead of sending an invalid PUT.
    ignore_changes = [
      name,
      response_export_values,
      body.properties.principalId,
      body.properties.roleDefinitionId,
      body.properties.delegatedManagedIdentityResourceId,
    ]

    postcondition {
      condition = (
        lower(self.body.properties.principalId) == lower(each.value.body.properties.principalId) &&
        lower(self.body.properties.roleDefinitionId) == lower(each.value.body.properties.roleDefinitionId) &&
        lower(coalesce(try(self.body.properties.delegatedManagedIdentityResourceId, null), "-")) == lower(coalesce(each.value.body.properties.delegatedManagedIdentityResourceId, "-"))
      )
      error_message = "An existing role assignment's principal, role definition or delegated identity cannot be changed under the same map key. First remove any scope locks in a separate apply, then remove this assignment and apply, then add the new assignment with a fresh GUID and apply. See the module upgrade guide. Automatic replacement is intentionally unsupported."
    }
  }
}

# =============================================================================
# AzureRM -> AzAPI state moves (`avm-tf-migration` SKILL.md L66-78)
#
# The provider migration is IN PLACE: same module, same `for_each`/`count`
# boundary, same keys, so every move is a whole-resource move and the consumer
# only bumps the module version. Plan with a normal refresh - `-refresh=false`
# and sovereign clouds hit azapi#1227 and plan a replace instead; those
# consumers need the `removed` + `import` fallback from the upgrade guide.
# =============================================================================
moved {
  from = azurerm_network_ddos_protection_plan.this
  to   = azapi_resource.this
}

moved {
  from = azurerm_management_lock.this[0]
  to   = azapi_resource.lock[0]
}

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignments
}
