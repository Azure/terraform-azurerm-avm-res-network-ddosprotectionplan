# terraform-azurerm-avm-res-network-ddosprotectionplan

Deploys an Azure DDoS protection plan with AzAPI, optional role assignments, tags, and a management lock.
The caller supplies an existing resource group through `parent_id`.
Virtual network associations are configured on the virtual networks; this module only reads them.

## Upgrading from v0.3.0 (AzureRM)

This is a breaking input change. Replace `resource_group_name` with the resource group's fully-qualified ARM `parent_id`.
Keep the module call's address, plan name, location, role-assignment map keys, and lock configuration unchanged during the upgrade.
Use Terraform `>= 1.9, < 2.0` and AzAPI `~> 2.12`; non-empty `ignore_body_changes` requires Terraform 1.11 or later.

The module owns these declarative state moves, including existing count/for_each instances and nested consumer module addresses:

| Released address | AzAPI address |
| --- | --- |
| `azurerm_network_ddos_protection_plan.this` | `azapi_resource.this` |
| `azurerm_management_lock.this[0]` | `azapi_resource.lock[0]` |
| `azurerm_role_assignment.this["key"]` | `azapi_resource.role_assignments["key"]` |

For ordinary ARM IDs, no migration flag, import block, `terraform state mv`, or importer tool is required.
The existing role-assignment GUIDs and default lock names/notes are retained.
Role names resolve case-insensitively at `parent_id`, rather than depending on a read of the plan resource.

1. Back up state to protected storage (`terraform state pull`), capture plan/lock/role-assignment IDs and associated virtual networks, and obtain a clean baseline plan using v0.3.0. Retain the existing AzureRM provider configuration and its locked provider version in the consumer root until the migration apply has completed; Terraform may still need it to read the old state.
2. Remove any `ReadOnly` lock in a separate baseline apply before upgrading; it blocks the in-place updates required by migration. If Terraform manages the lock, set `lock = null` and apply with the old module first. Remove inherited locks through their owner. Do not combine unrelated changes with the upgrade.
3. Update the module source/version and replace `resource_group_name` with `parent_id`. Run `terraform init -upgrade`, preserving the baseline AzureRM provider version while resolving the new AzAPI dependency.
4. Save and inspect `terraform plan -out=migration.tfplan` and its JSON (`terraform show -json migration.tfplan`). Expect the three applicable moves, possible in-place reconciliation, and new local UUID/sleep/telemetry resources. Telemetry-enabled upgrades can create subscription deployment records. **Do not apply if any existing plan, lock, role assignment, or association is deleted or replaced, or an unexplained infrastructure change appears.**
5. Apply only the inspected saved plan (`terraform apply migration.tfplan`). Verify unchanged ARM IDs, assignment GUIDs, lock details, outputs, and virtual network associations. Require a subsequent infrastructure plan with no changes. Enabled telemetry may update only its deployment timestamp; inspect that exact path rather than ignoring all telemetry drift.
6. Restore a removed `ReadOnly` lock in a separate apply after convergence. Remove unused consumer AzureRM configuration only once no remaining resources or state require it.

### Cross-tenant role assignments

AzureRM can store a delegated role assignment as `<ARM-ID>|<tenant-ID>`. AzAPI's state converter does not strip that suffix, so the standard move is **not supported for those instances**.
Before the candidate's first plan, record each exact ARM ID and GUID from the protected state backup, then remove only that binding and import the ordinary ARM ID at the new address. Keep the corresponding `role_assignments` key configured.
For example, in PowerShell for a consumer named `module.ddos`:

```powershell
terraform state rm 'module.ddos.azurerm_role_assignment.this["reader"]'
terraform import 'module.ddos.azapi_resource.role_assignments["reader"]' '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Network/ddosProtectionPlans/<plan>/providers/Microsoft.Authorization/roleAssignments/<existing-guid>?api-version=2022-04-01'
```

Replace the example address with the complete address from your own state (including any enclosing module instances). These commands change state, not Azure resources. If import fails, stop and recover that binding before applying anything. Do not remove other instances or regenerate assignment GUIDs.
This exceptional path requires separate state-backed verification and is not claimed as automated.

### Outputs and behavior

`name` and `resource_id` remain stable. `resource` is a compatibility object retaining `id`, `name`, `location`, `resource_group_name`, `tags`, and `virtual_network_ids`, not the raw AzAPI provider object. Provider-specific metadata such as `timeouts` is no longer exposed. Prefer the discrete `virtual_network_ids` output for computed associations.

Lock deletion waits 30 seconds before deleting the plan or its module-owned role assignments, allowing Azure lock removal to propagate. The new `lock.notes` input defaults to the released wording. Changes to immutable role-assignment inputs require replacement; remove any blocking lock separately before intentionally replacing an assignment.
The released module ignored role-assignment `description` and `principal_type`; these are now honored. If previously configured, review their first reconciliation explicitly.

### Verification and recovery

Mocked tests and fresh deployments do not prove an existing-state upgrade. Release readiness requires a v0.3.0 baseline apply, migration of that same state to the exact candidate, identity/association checks, convergence, and destruction through the candidate. Historical evidence from another commit is not evidence for this revision.
Do not assume reverting configuration or restoring an old state backup is a safe rollback after provider conversion or Azure updates. Preserve protected snapshots and inspect a recovery plan before taking further action.
