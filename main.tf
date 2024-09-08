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
      ip_rules = network_acls.value.ip_rules

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
