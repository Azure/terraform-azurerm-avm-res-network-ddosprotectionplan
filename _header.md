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
- **The `resource` output changes shape.** It is now the `azapi_resource` object: `id`, `name`,
  `location`, `parent_id`, `type`, `tags` and `body` are present; `resource_group_name` and
  `virtual_network_ids` are not. `resource_id` and `name` are unchanged.
- **Role assignments are not recreated.** The server-assigned role assignment GUID carried over by
  the `moved` block is pinned with `lifecycle.ignore_changes = [name]`, so existing assignments
  survive the upgrade untouched.
- **Minimum Terraform is now 1.9.** Cross-provider `moved` blocks require 1.8 or later.
