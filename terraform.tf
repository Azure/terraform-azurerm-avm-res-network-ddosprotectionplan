terraform {
  # `moved` across resource types (azurerm -> azapi) needs Terraform 1.8 or later.
  # 1.9 is the floor shared with the other migrated AVM resource modules.
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source = "Azure/azapi"
      # `~> 2.12` is the TFFR3 floor: 2.12 is the first release with
      # `ignore_body_changes`. The provider currently resolves to 2.13.0.
      version = "~> 2.12"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
