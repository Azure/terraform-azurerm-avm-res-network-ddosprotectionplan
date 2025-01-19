output "name" {
  description = "The name of the ddos protection plan resource."
  value       = azurerm_network_ddos_protection_plan.this.name
}

output "resource" {
  description = "The ddos protection plan resource."
  value       = azurerm_network_ddos_protection_plan.this
}

output "resource_id" {
  description = "The ID of the ddos protection plan resource."
  value       = azurerm_network_ddos_protection_plan.this.id
}
