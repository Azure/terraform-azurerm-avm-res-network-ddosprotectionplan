output "resource" {
  description = "DDoS plan details with the virtual network association IDs owned by this example."
  value = merge(module.ddosprotectionplan.resource, {
    virtual_network_ids = [azapi_resource.virtual_network.id]
  })
}
