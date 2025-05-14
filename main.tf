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
