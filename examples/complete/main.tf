locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  ais_name = "ais-${var.short}-${var.loc}-${terraform.workspace}-002"
  di_name  = "docintel-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  environment     = "prd"
  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-cognitive-account" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# Destination for the account diagnostics.
module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

# Complete call: two accounts.
#   1. An Azure AI Foundry (AIServices) account with project management enabled, a chat and an
#      embedding deployment, an extra custom "strict" RAI policy alongside the hardened default, and
#      the public endpoint flagged on but firewalled to an allow-list. (The module default is public
#      OFF; the examples turn it on so the behaviour is demonstrable.)
#   2. A Document Intelligence (FormRecognizer) account, public on but firewalled, no deployments.
module "cognitive_account" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  cognitive_accounts = {
    (local.ais_name) = {
      kind                          = "AIServices"
      project_management_enabled    = true
      public_network_access_enabled = true

      network_acls = {
        default_action = "Deny"
        bypass         = "AzureServices"
        ip_rules       = ["203.0.113.0/24"]
      }

      # Current GA models on the consumption (GlobalStandard) SKU. Model availability moves, so
      # confirm before pinning: az cognitiveservices model list --location uksouth -o table.
      deployments = {
        "gpt-5-mini" = {
          model = { name = "gpt-5-mini", version = "2025-08-07" }
          sku   = { name = "GlobalStandard", capacity = 10 }
        }
        "text-embedding-3-small" = {
          model = { name = "text-embedding-3-small", version = "1" }
          sku   = { name = "GlobalStandard", capacity = 10 }
        }
      }

      rai_policies = {
        "strict" = {
          mode = "Blocking"
          content_filters = [
            { name = "Hate", source = "Prompt", severity_threshold = "Low" },
            { name = "Hate", source = "Completion", severity_threshold = "Low" },
            { name = "Violence", source = "Prompt", severity_threshold = "Low" },
            { name = "Violence", source = "Completion", severity_threshold = "Low" },
          ]
        }
      }
    }

    (local.di_name) = {
      kind                          = "FormRecognizer"
      public_network_access_enabled = true

      network_acls = {
        default_action = "Deny"
        bypass         = "AzureServices"
        ip_rules       = ["203.0.113.0/24"]
      }
    }
  }
}

# Ship both accounts' logs and metrics to the workspace via the diagnostic-settings module.
module "diagnostics" {
  source  = "libre-devops/diagnostic-settings/azurerm"
  version = "~> 4.0"

  log_analytics_workspace_id = module.log_analytics.workspace_ids[local.law_name]

  diagnostic_settings = {
    "ais"      = { target_resource_id = module.cognitive_account.ids[local.ais_name] }
    "docintel" = { target_resource_id = module.cognitive_account.ids[local.di_name] }
  }
}
