output "name" {
  description = "The name of the ddos protection plan resource."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The ddos protection plan resource."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The ID of the ddos protection plan resource."
  value       = azapi_resource.this.id
}
