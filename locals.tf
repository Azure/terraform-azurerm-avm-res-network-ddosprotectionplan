locals {
  lock = var.lock == null ? null : merge(var.lock, {
    notes = var.lock.notes != null ? var.lock.notes : (var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources.")
  })
  role_definition_lookup_required = anytrue([
    for assignment in values(var.role_assignments) :
    !strcontains(lower(assignment.role_definition_id_or_name), local.role_definition_resource_substring)
  ])
  role_definition_ids_by_name = local.role_definition_lookup_required ? {
    for definition in data.azapi_resource_list.role_definitions[0].output.results :
    lower(definition.role_name) => definition.id...
  } : {}
  role_definition_resource_substring = "/providers/microsoft.authorization/roledefinitions/"
  role_assignments = {
    for key, assignment in var.role_assignments : key => merge(assignment, {
      principal_type = assignment.principal_type == null && assignment.skip_service_principal_aad_check ? "ServicePrincipal" : assignment.principal_type
      role_definition_id_or_name = (
        strcontains(lower(assignment.role_definition_id_or_name), local.role_definition_resource_substring) ?
        (startswith(lower(assignment.role_definition_id_or_name), "/providers/") ? "${local.subscription_resource_id}${assignment.role_definition_id_or_name}" : assignment.role_definition_id_or_name) :
        try(one(local.role_definition_ids_by_name[lower(assignment.role_definition_id_or_name)]), assignment.role_definition_id_or_name)
      )
    })
  }
  subscription_resource_id = "/subscriptions/${provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id).subscription_id}"
}
