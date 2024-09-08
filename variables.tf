variable "cognitive_accounts" {
  description = "The cognitive accounts to deploy"
  type = list(object({
    create                                       = optional(bool, true)
    location                                     = optional(string, "uksouth")
    name                                         = string
    rg_name                                      = string
    sku_name                                     = string
    tags                                         = map(string)
    kind                                         = string
    identity_type                                = optional(string)
    identity_ids                                 = optional(list(string))
    custom_subdomain_name                        = optional(string)
    dynamic_throttling_enabled                   = optional(bool)
    fqdns                                        = optional(list(string))
    local_auth_enabled                           = optional(bool)
    metrics_advisor_aad_client_id                = optional(string)
    metrics_advisor_aad_tenant_id                = optional(string)
    metrics_advisor_super_user_name              = optional(string)
    metrics_advisor_website_name                 = optional(string)
    outbound_network_access_restricted           = optional(bool)
    public_network_access_enabled                = optional(bool)
    qna_runtime_endpoint                         = optional(string)
    custom_question_answering_search_service_id  = optional(string)
    custom_question_answering_search_service_key = optional(string)
    network_acls = optional(object({
      default_action = optional(string)
      ip_rules       = optional(list(string))
      virtual_network_rules = optional(object({
        subnet_id                            = optional(string)
        ignore_missing_vnet_service_endpoint = optional(bool)
      }))
    }))
    customer_managed_key = optional(object({
      key_vault_key_id   = string
      identity_client_id = optional(string)
    }))
    storage = optional(object({
      storage_account_id = string
      identity_client_id = optional(string)
    }))
  }))
}
