output "name" {
  description = "The name of the ddos protection plan resource."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "Compatibility view of the DDoS protection plan with the AzureRM resource's public attributes. Prefer resource_id, name, and virtual_network_ids."
  value = {
    id                  = azapi_resource.this.id
    name                = azapi_resource.this.name
    location            = azapi_resource.this.location
    resource_group_name = provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id).resource_group_name
    tags                = azapi_resource.this.tags
    virtual_network_ids = try([for network in azapi_resource.this.output.properties.virtualNetworks : network.id], [])
  }
}

output "resource_id" {
  description = "The ID of the ddos protection plan resource."
  value       = azapi_resource.this.id
}

output "virtual_network_ids" {
  description = "The IDs of virtual networks associated with the DDoS protection plan. Associations are managed on the virtual networks, not by this module."
  value       = try([for network in azapi_resource.this.output.properties.virtualNetworks : network.id], [])
}
