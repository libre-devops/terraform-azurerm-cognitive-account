terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 4.47.0 added project_management_enabled and network_injection to
      # azurerm_cognitive_account, both of which this module exposes.
      version = ">= 4.47.0, < 5.0.0"
    }
  }
}
