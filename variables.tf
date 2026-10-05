# DDOS protection plan do not support diagnostic settings.


variable "location" {
  type        = string
  description = "The Azure location where the resources will be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "the name of the ddos protection plan"
}

# This is required for most resource modules
variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."

  validation {
    condition     = can(regex("^[a-zA-Z0-9_().-]{1,89}[a-zA-Z0-9_()-]$", var.resource_group_name))
    error_message = <<ERROR_MESSAGE
    The resource group name must meet the following requirements:
    - `Between 1 and 90 characters long.`
    - `Can only contain Alphanumerics, underscores, parentheses, hyphens, periods.`
    - `Cannot end in a period`
    ERROR_MESSAGE
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "ignore_body_changes" {
  type = object({
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    network_ddos_protection_plans  = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Body property paths whose changes the `azapi` provider ignores after creation, letting an out-of-band controller own those properties without producing perpetual `terraform plan` drift.

- `authorization_locks` - (Optional) Ignored body paths for the management lock, in dot notation relative to the request body, for example `["properties.notes"]`. Default `[]`.
- `authorization_role_assignments` - (Optional) Ignored body paths for the role assignments, in dot notation relative to the request body, for example `["properties.description"]`. Default `[]`.
- `network_ddos_protection_plans` - (Optional) Ignored body paths for the DDoS protection plan. Default `[]`.

While a path is ignored, configuration changes at that path are no longer sent to Azure. The value is write-only provider state, so a change only takes effect after an `apply`, and supplying a non-empty list requires Terraform 1.11 or later.

> Note: every property of `Microsoft.Network/ddosProtectionPlans` is read-only, so the module sends an empty `properties` object and `network_ddos_protection_plans` is close to inert. It is kept for shape-consistency with the sibling modules.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue(flatten([
      for paths in [
        var.ignore_body_changes.authorization_locks,
        var.ignore_body_changes.authorization_role_assignments,
        var.ignore_body_changes.network_ddos_protection_plans,
      ] : [for path in paths : length(trimspace(path)) > 0]
    ]))
    error_message = "Every ignore_body_changes entry must be a non-empty body path in dot notation, for example \"properties.notes\"."
  }
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`. When left `null` the module keeps the note text the pre-migration implementation wrote, so an existing lock is not modified on upgrade.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "resource_types" {
  type = object({
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    network_ddos_protection_plans  = optional(string, "Microsoft.Network/ddosProtectionPlans@2025-07-01")
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) The Azure resource type and API version used for each resource created by this module.

- `authorization_locks` - (Optional) The type and API version of the management lock. Default `Microsoft.Authorization/locks@2020-05-01`.
- `authorization_role_assignments` - (Optional) The type and API version of the role assignments. Default `Microsoft.Authorization/roleAssignments@2022-04-01`.
- `network_ddos_protection_plans` - (Optional) The type and API version of the DDoS protection plan. Default `Microsoft.Network/ddosProtectionPlans@2025-07-01`.

> Note: `network_ddos_protection_plans` must stay on the newest `Microsoft.Network` API version that the resolved `azapi` provider knows about. `moved` state conversion stamps the type on the migrated state row using that newest version, so a lower default would show up as a type change on the first plan after an upgrade. `2025-07-01` is the newest at azapi 2.13.0.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string), ["PrincipalNotFound", "LinkedAuthorizationFailed"])
    interval_seconds     = optional(number, 10)
    max_interval_seconds = optional(number, 180)
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Retry configuration applied to every `azapi_resource` in this module - the DDoS protection plan, the management lock and the role assignments.

- `error_message_regex` - (Optional) Regular expressions matched against the error message; a match makes the request retry.
- `interval_seconds` - (Optional) Base seconds between retries.
- `max_interval_seconds` - (Optional) Maximum seconds between retries.

The default preserves behaviour the pre-migration `azurerm_role_assignment` implemented in provider code rather than in configuration (`role_assignment_resource.go` L382-386 at provider v4.81.0): it retried a `400 PrincipalNotFound` while the principal replicated through Entra ID, and a `403 LinkedAuthorizationFailed` in the cross-tenant delegated-identity case. AzAPI has no equivalent built-in, so the same two conditions are expressed here.
DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on the <RESOURCE>. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the role assignment. Must be a valid GUID. If not set, a random UUID is generated. Changing this forces the creation of a new resource.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal. This field has no representation in the ARM request body; the pre-migration implementation used it to control a provider-side retry, which `retry.error_message_regex` now covers.

> Note: `description` and `principal_type` were accepted but never sent by the pre-migration implementation. They are sent now, so setting either produces a one-off in-place update on upgrade. When you leave them unset they are omitted from the request body entirely (the implementation sets `ignore_null_property = true`), which matches the pre-migration behaviour and keeps the plan free of the perpetual `principalType` diff Azure would otherwise cause by always returning a derived value.

> Note: `name` only takes effect when the role assignment is first created. The implementation carries `lifecycle.ignore_changes = [name]` so that the server-assigned GUID of an assignment created before the AzAPI migration survives the upgrade instead of being replaced; as a side effect, changing `name` on an existing assignment has no effect.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for role in var.role_assignments :
      role.name == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", coalesce(role.name, "00000000-0000-0000-0000-000000000000")))
    ])
    error_message = "Each `role_assignments[*].name` must be null or a valid GUID (e.g. `00000000-0000-0000-0000-000000000000`)."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "timeouts" {
  type = object({
    create = optional(string, "30m")
    delete = optional(string, "30m")
    read   = optional(string, "5m")
    update = optional(string, "30m")
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Timeouts applied to every `azapi_resource` in this module - the DDoS protection plan, the management lock and the role assignments.

Each value must be parsable as a Go duration, for example `"30s"`, `"5m"` or `"1h30m"`.

- `create` - (Optional) Timeout for create operations. Default `30m`.
- `delete` - (Optional) Timeout for delete operations. Default `30m`.
- `read` - (Optional) Timeout for read operations. Default `5m`.
- `update` - (Optional) Timeout for update operations. Default `30m`.

The defaults are the pre-migration `azurerm_network_ddos_protection_plan` per-resource defaults at provider v4.81.0 (`network_ddos_protection_plan_resource.go` L46-51), so the migration does not change how long an operation is allowed to run. Set the variable itself to `null` to fall back to the AzAPI provider defaults instead.
DESCRIPTION
}
