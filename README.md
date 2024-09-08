```hcl
resource "azurerm_cognitive_account" "accounts" {
  for_each = { for key, value in var.cognitive_accounts : key => value if value.create == true }

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
      default_action = try(each.value.network_acls.default_action, null)

      dynamic "ip_rules" {
        for_each = try(each.value.network_acls.ip_rules, []) != [] ? each.value.network_acls.ip_rules : []
        content {
          value = ip_rules.value
        }
      }

      dynamic "virtual_network_rules" {
        for_each = try(each.value.network_acls.virtual_network_rules, []) != [] ? [each.value.network_acls.virtual_network_rules] : []
        content {
          subnet_id                            = try(each.value.network_acls.virtual_network_rules.subnet_id, null)
          ignore_missing_vnet_service_endpoint = try(each.value.network_acls.virtual_network_rules.ignore_missing_vnet_service_endpoint, false)
        }
      }
    }
  }

  dynamic "customer_managed_key" {
    for_each = each.value.customer_managed_key != null ? [each.value.customer_managed_key] : []
    content {
      key_vault_key_id   = each.value.customer_managed_key.key_vault_key_id
      identity_client_id = try(each.value.customer_managed_key.identity_client_id, null)
    }
  }

  dynamic "storage" {
    for_each = each.value.storage != null ? [each.value.storage] : []
    content {
      storage_account_id = each.value.storage.storage_account_id
      identity_client_id = try(each.value.storage.identity_client_id, null)
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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cognitive_accounts"></a> [cognitive\_accounts](#input\_cognitive\_accounts) | The cognitive accounts to deploy | <pre>list(object({<br>    create                                       = optional(bool, true)<br>    location                                     = optional(string, "uksouth")<br>    name                                         = string<br>    rg_name                                      = string<br>    sku_name                                     = string<br>    tags                                         = map(string)<br>    kind                                         = string<br>    identity_type                                = optional(string)<br>    identity_ids                                 = optional(list(string))<br>    custom_subdomain_name                        = optional(string)<br>    dynamic_throttling_enabled                   = optional(bool)<br>    fqdns                                        = optional(list(string))<br>    local_auth_enabled                           = optional(bool)<br>    metrics_advisor_aad_client_id                = optional(string)<br>    metrics_advisor_aad_tenant_id                = optional(string)<br>    metrics_advisor_super_user_name              = optional(string)<br>    metrics_advisor_website_name                 = optional(string)<br>    outbound_network_access_restricted           = optional(bool)<br>    public_network_access_enabled                = optional(bool)<br>    qna_runtime_endpoint                         = optional(string)<br>    custom_question_answering_search_service_id  = optional(string)<br>    custom_question_answering_search_service_key = optional(string)<br>    network_acls = optional(object({<br>      default_action = optional(string)<br>      ip_rules       = optional(list(string))<br>      virtual_network_rules = optional(object({<br>        subnet_id                            = optional(string)<br>        ignore_missing_vnet_service_endpoint = optional(bool)<br>      }))<br>    }))<br>    customer_managed_key = optional(object({<br>      key_vault_key_id   = string<br>      identity_client_id = optional(string)<br>    }))<br>    storage = optional(object({<br>      storage_account_id = string<br>      identity_client_id = optional(string)<br>    }))<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cognitive_account_endpoints"></a> [cognitive\_account\_endpoints](#output\_cognitive\_account\_endpoints) | The endpoints of the Cognitive Service Accounts. |
| <a name="output_cognitive_account_identities"></a> [cognitive\_account\_identities](#output\_cognitive\_account\_identities) | The identity blocks for the Cognitive Service Accounts, including principal\_id and tenant\_id. |
| <a name="output_cognitive_account_ids"></a> [cognitive\_account\_ids](#output\_cognitive\_account\_ids) | The IDs of the Cognitive Service Accounts. |
| <a name="output_cognitive_account_primary_access_keys"></a> [cognitive\_account\_primary\_access\_keys](#output\_cognitive\_account\_primary\_access\_keys) | The primary access keys for the Cognitive Service Accounts. |
| <a name="output_cognitive_account_secondary_access_keys"></a> [cognitive\_account\_secondary\_access\_keys](#output\_cognitive\_account\_secondary\_access\_keys) | The secondary access keys for the Cognitive Service Accounts. |
