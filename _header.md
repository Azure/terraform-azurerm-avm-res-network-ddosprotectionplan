# terraform-azurerm-avm-res-network-ddosprotectionplan

Module to enable DDoS protection plan in Azure

> [!WARNING]
> A DDoS Network Protection plan carries a flat monthly charge, prorated by the hour, from the moment the plan exists - whether or not any virtual network is associated with it. See the [Azure DDoS Protection pricing page](https://azure.microsoft.com/pricing/details/ddos-protection/) for the current rate before deploying one for testing.

## Upgrading from v0.3.0 and earlier

This release migrates the module from the `azurerm` provider to `azapi`. The module keeps the same
inputs and the same resource addresses, so in the normal case a consumer only bumps the module
version - the in-module `moved` blocks convert the existing state rows in place, with no destroy and
no replacement.

What you need to know:

- **Plan with a normal refresh.** `terraform plan -refresh=false`, and any sovereign cloud, hit
  [azapi#1227](https://github.com/Azure/terraform-provider-azapi/issues/1227) and plan a *replace*
  instead of a move. Those cases need a `removed` + `import` upgrade path rather than `moved`.
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
