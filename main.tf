# Cognitive Services accounts keyed by name, with secure defaults: Entra-only auth (local_auth off),
# no public endpoint by default, a system-assigned identity, and a custom subdomain (needed for token
# auth and Foundry project management). For OpenAI / AIServices accounts a hardened default RAI policy
# (Content Safety harm filters on prompts and completions, plus Prompt Shields) is built and attached
# to every deployment that does not name its own policy. The resource group is passed by id and parsed.
locals {
  rg                  = provider::azurerm::parse_resource_id(var.resource_group_id)
  resource_group_name = local.rg.resource_group_name

  # Accounts that get the hardened default RAI policy. The opt-in resolves to true for OpenAI /
  # AIServices unless the caller overrides it; RAI policies apply only to those kinds.
  default_rai_accounts = {
    for name, a in var.cognitive_accounts : name => a
    if coalesce(a.create_default_rai_policy, contains(["OpenAI", "AIServices"], a.kind))
  }

  harm_categories = ["Hate", "Sexual", "Violence", "Selfharm"]

  # Content filters for each default policy: the four harm categories on both prompt and completion,
  # plus the two Prompt Shields (Jailbreak and Indirect Attack / XPIA, prompt-source only) when
  # enabled. Names use the API's PascalCase to avoid perpetual drift (provider issue #31632). The
  # Prompt Shield severity has no effect but the provider requires a value, so it is set to High.
  default_rai_filters = {
    for name, a in local.default_rai_accounts : name => concat(
      flatten([
        for category in local.harm_categories : [
          for direction in ["Prompt", "Completion"] : {
            name               = category
            source             = direction
            filter_enabled     = true
            block_enabled      = true
            severity_threshold = a.default_rai_policy.severity_threshold
          }
        ]
      ]),
      a.default_rai_policy.enable_prompt_shields ? [
        { name = "Jailbreak", source = "Prompt", filter_enabled = true, block_enabled = true, severity_threshold = "High" },
        { name = "Indirect Attack", source = "Prompt", filter_enabled = true, block_enabled = true, severity_threshold = "High" },
      ] : []
    )
  }

  # Deterministic default-policy name per account, referenced by deployments that do not set their own.
  default_rai_policy_name = {
    for name, a in local.default_rai_accounts : name => coalesce(a.default_rai_policy.name, "${name}-rai")
  }

  # Flatten caller-supplied custom RAI policies to "<account>/<policy>" keys.
  custom_rai_policies = merge([
    for acc_name, a in var.cognitive_accounts : {
      for pol_name, p in a.rai_policies : "${acc_name}/${pol_name}" => {
        account_name     = acc_name
        policy_name      = pol_name
        base_policy_name = p.base_policy_name
        mode             = p.mode
        tags             = p.tags
        content_filters  = p.content_filters
      }
    }
  ]...)

  # Flatten deployments to "<account>/<deployment>" keys, resolving the RAI policy each targets:
  # an explicit per-deployment policy, else the account's default policy, else none.
  deployments = merge([
    for acc_name, a in var.cognitive_accounts : {
      for dep_name, d in a.deployments : "${acc_name}/${dep_name}" => {
        account_name               = acc_name
        deployment_name            = dep_name
        model                      = d.model
        sku                        = d.sku
        version_upgrade_option     = d.version_upgrade_option
        dynamic_throttling_enabled = d.dynamic_throttling_enabled
        rai_policy_name            = d.rai_policy_name != null ? d.rai_policy_name : lookup(local.default_rai_policy_name, acc_name, null)
      }
    }
  ]...)
}

resource "azurerm_cognitive_account" "this" {
  for_each = var.cognitive_accounts

  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = var.tags

  name     = each.key
  kind     = each.value.kind
  sku_name = each.value.sku_name

  # Defaults to the account name; required for Entra token auth and Foundry project management.
  custom_subdomain_name              = coalesce(each.value.custom_subdomain_name, each.key)
  local_auth_enabled                 = each.value.local_auth_enabled
  public_network_access_enabled      = each.value.public_network_access_enabled
  project_management_enabled         = each.value.project_management_enabled
  dynamic_throttling_enabled         = each.value.dynamic_throttling_enabled
  fqdns                              = each.value.fqdns
  outbound_network_access_restricted = each.value.outbound_network_access_restricted

  metrics_advisor_aad_client_id                = each.value.metrics_advisor_aad_client_id
  metrics_advisor_aad_tenant_id                = each.value.metrics_advisor_aad_tenant_id
  metrics_advisor_super_user_name              = each.value.metrics_advisor_super_user_name
  metrics_advisor_website_name                 = each.value.metrics_advisor_website_name
  qna_runtime_endpoint                         = each.value.qna_runtime_endpoint
  custom_question_answering_search_service_id  = each.value.custom_question_answering_search_service_id
  custom_question_answering_search_service_key = each.value.custom_question_answering_search_service_key

  dynamic "identity" {
    for_each = each.value.identity != null ? [each.value.identity] : []

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "network_acls" {
    for_each = each.value.network_acls != null ? [each.value.network_acls] : []

    content {
      default_action = network_acls.value.default_action
      bypass         = network_acls.value.bypass
      ip_rules       = network_acls.value.ip_rules

      dynamic "virtual_network_rules" {
        for_each = network_acls.value.virtual_network_rules

        content {
          subnet_id                            = virtual_network_rules.value.subnet_id
          ignore_missing_vnet_service_endpoint = virtual_network_rules.value.ignore_missing_vnet_service_endpoint
        }
      }
    }
  }

  dynamic "network_injection" {
    for_each = each.value.network_injection != null ? [each.value.network_injection] : []

    content {
      scenario  = network_injection.value.scenario
      subnet_id = network_injection.value.subnet_id
    }
  }

  dynamic "customer_managed_key" {
    for_each = each.value.customer_managed_key != null ? [each.value.customer_managed_key] : []

    content {
      key_vault_key_id   = customer_managed_key.value.key_vault_key_id
      identity_client_id = customer_managed_key.value.identity_client_id
    }
  }

  dynamic "storage" {
    for_each = each.value.storage != null ? [each.value.storage] : []

    content {
      storage_account_id = storage.value.storage_account_id
      identity_client_id = storage.value.identity_client_id
    }
  }
}

# The hardened default Responsible AI policy, one per OpenAI / AIServices account (unless opted out).
resource "azurerm_cognitive_account_rai_policy" "default" {
  for_each = local.default_rai_accounts

  name                 = local.default_rai_policy_name[each.key]
  cognitive_account_id = azurerm_cognitive_account.this[each.key].id
  base_policy_name     = each.value.default_rai_policy.base_policy_name
  mode                 = each.value.default_rai_policy.mode
  tags                 = var.tags

  dynamic "content_filter" {
    for_each = local.default_rai_filters[each.key]

    content {
      name               = content_filter.value.name
      source             = content_filter.value.source
      filter_enabled     = content_filter.value.filter_enabled
      block_enabled      = content_filter.value.block_enabled
      severity_threshold = content_filter.value.severity_threshold
    }
  }
}

# Caller-supplied custom Responsible AI policies.
resource "azurerm_cognitive_account_rai_policy" "custom" {
  for_each = local.custom_rai_policies

  name                 = each.value.policy_name
  cognitive_account_id = azurerm_cognitive_account.this[each.value.account_name].id
  base_policy_name     = each.value.base_policy_name
  mode                 = each.value.mode
  tags                 = each.value.tags != null ? each.value.tags : var.tags

  dynamic "content_filter" {
    for_each = each.value.content_filters

    content {
      name               = content_filter.value.name
      source             = content_filter.value.source
      filter_enabled     = content_filter.value.filter_enabled
      block_enabled      = content_filter.value.block_enabled
      severity_threshold = content_filter.value.severity_threshold
    }
  }
}

resource "azurerm_cognitive_deployment" "this" {
  for_each = local.deployments

  name                       = each.value.deployment_name
  cognitive_account_id       = azurerm_cognitive_account.this[each.value.account_name].id
  rai_policy_name            = each.value.rai_policy_name
  version_upgrade_option     = each.value.version_upgrade_option
  dynamic_throttling_enabled = each.value.dynamic_throttling_enabled

  model {
    format  = each.value.model.format
    name    = each.value.model.name
    version = each.value.model.version
  }

  sku {
    name     = each.value.sku.name
    tier     = each.value.sku.tier
    size     = each.value.sku.size
    family   = each.value.sku.family
    capacity = each.value.sku.capacity
  }

  # Deployments name their RAI policy as a string, so the policies must exist first.
  depends_on = [
    azurerm_cognitive_account_rai_policy.default,
    azurerm_cognitive_account_rai_policy.custom,
  ]
}
