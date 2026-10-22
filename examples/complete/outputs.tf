output "public_ip_ddos_protection_plan_id" {
  description = "The DDoS protection plan ID returned by Azure for the public IP association."
  value       = azapi_resource.public_ip.output.properties.ddosSettings.ddosProtectionPlan.id
}

output "public_ip_resource_id" {
  description = "The resource ID of the Standard public IP associated with the DDoS protection plan."
  value       = azapi_resource.public_ip.id
}

output "resource" {
  description = "The ddos protection plan resource."
  value       = module.ddosprotectionplan.resource
}
