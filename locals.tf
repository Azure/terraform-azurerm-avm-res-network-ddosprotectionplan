locals {
  avm_azapi_header = join(" ", [for k, v in local.avm_azapi_headers : "${k}=${v}"])
  avm_azapi_headers = !var.enable_telemetry ? {} : {
    avm_module_source  = one(data.modtm_module_source.telemetry).module_source
    avm_module_version = one(data.modtm_module_source.telemetry).module_version
    random_id          = one(random_uuid.telemetry).result
  }
}
