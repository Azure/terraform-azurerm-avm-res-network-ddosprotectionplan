# terraform-azurerm-avm-res-network-ddosprotectionplan

Module to enable DDoS protection plan in Azure

> [!WARNING]
> A DDoS Network Protection plan carries a flat monthly charge, prorated by the hour, from the moment the plan exists - whether or not any virtual network is associated with it. See the [Azure DDoS Protection pricing page](https://azure.microsoft.com/pricing/details/ddos-protection/) for the current rate before deploying one for testing.

## Upgrading from v0.3.0 and earlier

This release migrates the module from the `azurerm` provider to `azapi`. The in-module `moved` blocks
map existing AzureRM state to the AzAPI resources. Review the upgrade plan before applying it.

What you need to know:

- **Plan with refresh enabled.** Use Terraform's default refresh when planning the upgrade. Review
  the plan and stop if it shows an unexpected replacement of the DDoS plan or its role assignments.
- **Keep an `azurerm` provider block in the root module for the upgrade apply.** Terraform must be
  able to read the pre-migration state rows before the `moved` blocks convert them. The block can be
  removed afterwards. The `default` example shows this, commented out.
- **The `resource` output changes shape.** It is a six-field projection containing only `id`,
  `location`, `name`, `parent_id`, `tags` and `type`. It is not the whole `azapi_resource` object.
  `body`, `resource_group_name` and `virtual_network_ids` are not available. `resource_id` and
  `name` are unchanged.
- **Role assignments are not recreated.** The server-assigned role assignment GUID carried over by
  the `moved` block is pinned with `lifecycle.ignore_changes = [name]`, so existing assignments
  survive the upgrade untouched.
- **Minimum Terraform is now 1.9.** Cross-provider `moved` blocks require 1.8 or later.

## Updating role assignments and locks

An existing role assignment's principal, role definition and delegated managed identity are
immutable. Editing those fields under the same map key fails the plan with a staged replacement
message. The module retains the immutable values in state and checks them against the requested
values; it does not silently ignore the edit or send an invalid in-place PUT.
Automatic replacement is deliberately unsupported because the adopted GUID must remain stable
and a `CanNotDelete` lock blocks role-assignment deletion.

To replace an assignment, review and apply each stage separately:

1. Keep the old assignment unchanged. Set this module's `lock` to `null` and apply. Have the
   owners of any inherited resource-group or subscription locks remove those locks too. Confirm
   that lock removal has propagated before proceeding.
2. Remove the old entry from `role_assignments` and apply. Review the plan to confirm it deletes
   only the intended assignment. This temporarily revokes its access, so use a separate
   authorized identity to perform the procedure.
3. Add the replacement assignment and apply with locks still removed. A new map key with
   `name = null` generates a fresh GUID. Never reuse the previous explicit GUID for a different
   principal or role.
4. Restore the desired locks in a separate apply after the new assignment is present.

Use the same staged unlock before deleting an assignment while keeping the DDoS plan. A
`ReadOnly` lock also blocks mutable updates and new assignments, so remove it in a separate
apply before changing conditions or descriptions. The module creates its lock after its role
assignments and removes it first during a full destroy. This graph order does not remove an
unchanged lock during an ordinary update, and it cannot remove inherited locks.

`condition` and `condition_version` remain mutable. Setting `condition` to `null`, omitting it,
or setting it to `""` sends both ARM condition fields as explicit JSON nulls to
[remove the condition](https://learn.microsoft.com/azure/role-based-access-control/conditions-role-assignments-powershell#delete-a-condition).
ARM does not accept an empty-string `conditionVersion`. The module preserves the reset nulls
with `ignore_null_property = false`, but removes unset `principal_type` from the body before
sending it, avoiding perpetual diffs against Azure's derived principal type.
Consumer-selected `ignore_body_changes` on condition paths deliberately
prevents condition changes from being sent until those paths are removed and applied.

## Location changes

Cross-region relocation of an existing DDoS protection plan is not supported. Azure rejects an
in-place cross-region location update; do not treat a changed `location` as an ordinary mutable
update. Review the provider's plan and stop before an unintended replacement. Deploy a separate
plan in the destination region and migrate its virtual network associations through their owning
configurations instead. This is a migration limitation, not a promise of AzureRM's location
replacement behavior.
