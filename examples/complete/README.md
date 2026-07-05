<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

Exercises the fuller surface of this module. The environment comes from the Terraform workspace
(`terraform.workspace`), not a variable. Run it with `just e2e complete`, which applies the stack
then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
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

      # FormRecognizer (Document Intelligence) does not support network_acls.bypass, so it is omitted
      # here (unlike the AIServices account above, which can bypass for trusted Azure services).
      network_acls = {
        default_action = "Deny"
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
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cognitive_account"></a> [cognitive\_account](#module\_cognitive\_account) | ../../ | n/a |
| <a name="module_diagnostics"></a> [diagnostics](#module\_diagnostics) | libre-devops/diagnostic-settings/azurerm | ~> 4.0 |
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_ids"></a> [account\_ids](#output\_account\_ids) | Map of account name to resource id. |
| <a name="output_deployment_ids"></a> [deployment\_ids](#output\_deployment\_ids) | Map of "<account>/<deployment>" to deployment id. |
| <a name="output_endpoints"></a> [endpoints](#output\_endpoints) | Map of account name to its endpoint. |
| <a name="output_rai_policy_ids"></a> [rai\_policy\_ids](#output\_rai\_policy\_ids) | Map of RAI policy key to id (default policies by account name, custom by "<account>/<policy>"). |
<!-- END_TF_DOCS -->
