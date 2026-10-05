# Unconditional client config. `main.telemetry.tf` declares its own, count-gated,
# `data.azapi_client_config.telemetry`; this one has to be always present because
# `local.parent_id` and the role-definition lookup scope are needed whether or not
# telemetry is enabled.
data "azapi_client_config" "current" {}
