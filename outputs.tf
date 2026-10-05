output "name" {
  description = "The name of the ddos protection plan resource."
  value       = azapi_resource.this.name
}

output "resource" {
  description = <<DESCRIPTION
The ddos protection plan resource.

This is a discrete projection of `azapi_resource.this`, not the whole resource object: `id`, `location`, `name`, `parent_id`, `tags` and `type`. The former `azurerm_network_ddos_protection_plan` attributes `resource_group_name` and `virtual_network_ids` are not available. Read the list of protected virtual networks from the virtual networks themselves rather than from the plan - the back-reference is populated by Azure across subscriptions and state files, so it is not exported here.
DESCRIPTION
  value = {
    id        = azapi_resource.this.id
    location  = azapi_resource.this.location
    name      = azapi_resource.this.name
    parent_id = azapi_resource.this.parent_id
    tags      = azapi_resource.this.tags
    type      = azapi_resource.this.type
  }
}

output "resource_id" {
  description = "The ID of the ddos protection plan resource."
  value       = azapi_resource.this.id
}
