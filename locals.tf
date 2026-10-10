locals {
  # ---------------------------------------------------------------------------
  # Lock body parity with the pre-migration `azurerm_management_lock.this`.
  #
  # The public `lock` variable carries the canonical AVM variant-2 shape
  # (`kind` + `name` + `notes`). The pre-migration resource derived `notes` from
  # `kind` and never let the caller set it, so when `notes` is left null the
  # same derivation is applied here before the object is handed to the
  # interfaces module. Without it the first plan after the `moved` block would
  # show `properties.notes` being cleared on every existing lock.
  # ---------------------------------------------------------------------------
  lock = var.lock == null ? null : {
    kind  = var.lock.kind
    name  = var.lock.name
    notes = coalesce(var.lock.notes, var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources.")
  }
  # ---------------------------------------------------------------------------
  # Parent scope.
  #
  # DEVIATION from `avm-tf-azapi` SKILL.md "Parent scope validation", which asks
  # a resource module to take a required `parent_id` and never to construct one
  # from `resource_group_name`. This release is a provider migration IN PLACE:
  # the module keeps the same inputs so that existing consumers - including the
  # `avm-ptn-alz-connectivity-virtual-wan` pattern module - only bump the module
  # version. Swapping `resource_group_name` for `parent_id` is an input-breaking
  # change and belongs in the next major, not in the release that carries the
  # state move. The same construction is used by the vWAN pattern module's
  # submodules for the same reason.
  # ---------------------------------------------------------------------------
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}
