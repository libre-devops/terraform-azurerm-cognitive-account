```hcl
resource "azurerm_cognitive_account" "accounts" {
  for_each = { for account in var.cognitive_accounts : account.name => account if account.create == true }

  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.rg_name
  tags                = each.value.tags

  sku_name                                     = upper(each.value.sku_name)
  kind                                         = each.value.kind
  custom_subdomain_name                        = try(each.value.custom_subdomain_name, null)
  dynamic_throttling_enabled                   = try(each.value.dynamic_throttling_enabled, null)
  fqdns                                        = try(each.value.fqdns, [])
  local_auth_enabled                           = try(each.value.local_auth_enabled, null)
  metrics_advisor_aad_client_id                = try(each.value.metrics_advisor_aad_client_id, null)
  metrics_advisor_aad_tenant_id                = try(each.value.metrics_advisor_aad_tenant_id, null)
  metrics_advisor_super_user_name              = try(each.value.metrics_advisor_super_user_name, null)
  metrics_advisor_website_name                 = try(each.value.metrics_advisor_website_name, null)
  outbound_network_access_restricted           = try(each.value.outbound_network_access_restricted, null)
  public_network_access_enabled                = try(each.value.public_network_access_enabled, null)
  qna_runtime_endpoint                         = try(each.value.qna_runtime_endpoint, null)
  custom_question_answering_search_service_id  = try(each.value.custom_question_answering_search_service_id, null)
  custom_question_answering_search_service_key = try(each.value.custom_question_answering_search_service_key, null)

  dynamic "identity" {
    for_each = each.value.identity_type == "SystemAssigned" ? [each.value.identity_type] : []
    content {
      type = each.value.identity_type
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == "SystemAssigned, UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = try(each.value.identity_ids, [])
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == "UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = length(try(each.value.identity_ids, [])) > 0 ? each.value.identity_ids : []
    }
  }

  dynamic "network_acls" {
    for_each = each.value.network_acls != null ? [each.value.network_acls] : []
    content {
      default_action = try(network_acls.value.default_action, null)
      ip_rules       = network_acls.value.ip_rules
      bypass         = try(network_acls.value.bypass, null)

      dynamic "virtual_network_rules" {
        for_each = network_acls.value.virtual_network_rules != null ? network_acls.value.virtual_network_rules : []
        content {
          subnet_id                            = virtual_network_rules.value.subnet_id
          ignore_missing_vnet_service_endpoint = try(virtual_network_rules.value.ignore_missing_vnet_service_endpoint, false)
        }
      }
    }
  }

  dynamic "customer_managed_key" {
    for_each = each.value.customer_managed_key != null ? [each.value.customer_managed_key] : []
    content {
      key_vault_key_id   = customer_managed_key.value.key_vault_key_id
      identity_client_id = try(customer_managed_key.value.identity_client_id, null)
    }
  }

  dynamic "storage" {
    for_each = each.value.storage != null ? [each.value.storage] : []
    content {
      storage_account_id = storage.value.storage_account_id
      identity_client_id = try(storage.value.identity_client_id, null)
    }
  }
}


locals {
  deployments = flatten([
    for account in var.cognitive_accounts : [
      for deployment in account.model_deployments != null ? account.model_deployments : [] : {
        account_name               = account.name
        account_rg_name            = account.rg_name
        account_location           = account.location
        deployment_name            = try(deployment.deployment_name, null)
        dynamic_throttling_enabled = deployment.dynamic_throttling_enabled
        rai_policy_name            = deployment.rai_policy_name
        deployment_sku_name        = deployment.deployment_sku.name
        deployment_sku_tier        = deployment.deployment_sku.tier
        deployment_sku_size        = deployment.deployment_sku.size
        deployment_sku_family      = deployment.deployment_sku.family
        deployment_sku_capacity    = deployment.deployment_sku.capacity
        deployment_model_format    = deployment.deployment_model.format
        deployment_model_name      = deployment.deployment_model.name
        deployment_model_version   = deployment.deployment_model.version
      }
    ]
  ])
}

resource "azurerm_cognitive_deployment" "deployment" {
  for_each = { for index, deployment in local.deployments : index => merge(deployment, { index = index }) }

  name                       = each.value.deployment_name == null ? "${each.value.account_name}-${each.value.account_location}-${each.value.deployment_model_name}-${format("%02d", each.value.index + 1)}" : each.value.deployment_name # The format function here applies number padding to the index of the each item in the for loop e.g. 1 -> 01.  Terraform index's start at 0, so + 1 ensures they start 01, 02, 03 etc
  cognitive_account_id       = azurerm_cognitive_account.accounts[each.value.account_name].id
  dynamic_throttling_enabled = each.value.dynamic_throttling_enabled
  rai_policy_name            = each.value.rai_policy_name

  dynamic "model" {
    for_each = each.value.deployment_model_name != null ? [each.value.deployment_model_name] : []
    content {
      format  = each.value.deployment_model_format
      name    = each.value.deployment_model_name
      version = each.value.deployment_model_version
    }
  }

  dynamic "sku" {
    for_each = each.value.deployment_sku_name != null ? [each.value.deployment_sku_name] : []
    content {
      name     = each.value.deployment_sku_name
      tier     = each.value.deployment_sku_tier
      size     = each.value.deployment_sku_size
      family   = each.value.deployment_sku_family
      capacity = each.value.deployment_sku_capacity
    }
  }
}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_cognitive_account.accounts](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_account) | resource |
| [azurerm_cognitive_deployment.deployment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cognitive_accounts"></a> [cognitive\_accounts](#input\_cognitive\_accounts) | The cognitive accounts to deploy | <pre>list(object({<br/>    create                  = optional(bool, true)<br/>    location                = optional(string, "uksouth")<br/>    name                    = string<br/>    rg_name                 = string<br/>    sku_name                = string<br/>    tags                    = map(string)<br/>    kind                    = string<br/>    identity_type           = optional(string)<br/>    identity_ids            = optional(list(string))<br/>    custom_subdomain_name   = optional(string)<br/>    create_model_deployment = optional(bool, false)<br/>    model_deployments = optional(list(object({<br/>      deployment_name            = optional(string)<br/>      dynamic_throttling_enabled = optional(bool)<br/>      rai_policy_name            = optional(string)<br/>      version_upgrade_option     = optional(string, "OnceNewDefaultVersionAvailable")<br/>      deployment_sku = optional(object({<br/>        name     = optional(string, "GlobalStandard")<br/>        tier     = optional(string)<br/>        size     = optional(string)<br/>        family   = optional(string)<br/>        capacity = optional(string)<br/>      }))<br/>      deployment_model = optional(object({<br/>        format  = optional(string)<br/>        name    = optional(string)<br/>        version = optional(string)<br/>      }))<br/>    })))<br/>    dynamic_throttling_enabled                   = optional(bool)<br/>    fqdns                                        = optional(list(string))<br/>    local_auth_enabled                           = optional(bool, false)<br/>    metrics_advisor_aad_client_id                = optional(string)<br/>    metrics_advisor_aad_tenant_id                = optional(string)<br/>    metrics_advisor_super_user_name              = optional(string)<br/>    metrics_advisor_website_name                 = optional(string)<br/>    outbound_network_access_restricted           = optional(bool)<br/>    public_network_access_enabled                = optional(bool, false)<br/>    qna_runtime_endpoint                         = optional(string)<br/>    custom_question_answering_search_service_id  = optional(string)<br/>    custom_question_answering_search_service_key = optional(string)<br/>    network_acls = optional(object({<br/>      default_action = optional(string)<br/>      bypass         = optional(string)<br/>      ip_rules       = optional(list(string))<br/>      virtual_network_rules = optional(list(object({<br/>        subnet_id                            = optional(string)<br/>        ignore_missing_vnet_service_endpoint = optional(bool)<br/>      })))<br/>    }))<br/>    customer_managed_key = optional(object({<br/>      key_vault_key_id   = string<br/>      identity_client_id = optional(string)<br/>    }))<br/>    storage = optional(object({<br/>      storage_account_id = string<br/>      identity_client_id = optional(string)<br/>    }))<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cognitive_account_endpoints"></a> [cognitive\_account\_endpoints](#output\_cognitive\_account\_endpoints) | The endpoints of the Cognitive Service Accounts. |
| <a name="output_cognitive_account_identities"></a> [cognitive\_account\_identities](#output\_cognitive\_account\_identities) | The identity blocks for the Cognitive Service Accounts, including principal\_id and tenant\_id. |
| <a name="output_cognitive_account_ids"></a> [cognitive\_account\_ids](#output\_cognitive\_account\_ids) | The IDs of the Cognitive Service Accounts. |
| <a name="output_cognitive_account_primary_access_keys"></a> [cognitive\_account\_primary\_access\_keys](#output\_cognitive\_account\_primary\_access\_keys) | The primary access keys for the Cognitive Service Accounts. |
| <a name="output_cognitive_account_secondary_access_keys"></a> [cognitive\_account\_secondary\_access\_keys](#output\_cognitive\_account\_secondary\_access\_keys) | The secondary access keys for the Cognitive Service Accounts. |
