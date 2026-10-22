variable "ddos_plan_location" {
  type        = string
  default     = "westus"
  description = <<DESCRIPTION
This variable defines the Azure region where the DDOS protection plan will be created.
The default value is "westus".
DESCRIPTION
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "ignore_body_changes" {
  type = object({
    resources_resource_groups = optional(list(string), [])
    network_virtual_networks  = optional(list(string), [])
  })
  default     = {}
  description = "Body-relative dot-notation paths ignored on `resources_resource_groups` and `network_virtual_networks`. Ignored configuration is not sent to Azure; changes take effect after apply."
  nullable    = false
}

variable "resource_types" {
  type = object({
    resources_resource_groups = optional(string, "Microsoft.Resources/resourceGroups@2025-04-01")
    network_virtual_networks  = optional(string, "Microsoft.Network/virtualNetworks@2024-05-01")
  })
  default     = {}
  description = "AzAPI resource types and API versions: `resources_resource_groups` for the resource group and `network_virtual_networks` for the associated virtual network."
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = "Retry controls for supporting AzAPI resources: error message patterns, initial interval in seconds, and maximum interval in seconds."
}

variable "rg_location" {
  type        = string
  default     = "westus"
  description = <<DESCRIPTION
This variable defines the Azure region where the resource group will be created.
The default value is "westus".
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = "Supporting resource operation timeouts: create, read, update, and delete, as Go duration strings."
}
