variable "cognitive_accounts" {
  description = <<-EOT
    Cognitive Services accounts to create, keyed by account name. One entry provisions one account
    (any kind: AIServices for Azure AI Foundry, OpenAI, FormRecognizer for Document Intelligence,
    ContentSafety, SpeechServices, ...) plus, optionally, its model deployments and Responsible AI
    (RAI) policies.

    Secure defaults, all caller-overridable:
      - local_auth_enabled = false          (Entra ID token auth only, account keys off)
      - public_network_access_enabled = false (not reachable over the public endpoint; pair with a
                                              private endpoint, or set true with a network_acls
                                              allow-list)
      - identity.type = SystemAssigned      (the account gets an Entra identity)
      - custom_subdomain_name = <the account name> (required for Entra token auth and for Foundry
                                              project management; must be globally unique)
      - a hardened default RAI policy is built for OpenAI / AIServices accounts (Content Safety harm
        filters on prompts and completions plus Prompt Shields) and attached to every deployment that
        does not name its own policy. Set create_default_rai_policy = false to opt out.

    Per-account fields:
      kind                          Account kind. Drives the naming prefix in the rego (oai-, ais-,
                                    docintel-, cog-). Defaults to AIServices (the unified Foundry
                                    resource).
      sku_name                      Account SKU. S0 is standard pay-as-you-go.
      custom_subdomain_name         Globally unique subdomain. Defaults to the account name.
      local_auth_enabled            Whether account keys work. Default false (Entra-only).
      public_network_access_enabled Public endpoint reachability. Default false.
      project_management_enabled    AIServices only: enables Azure AI Foundry projects under this
                                    account (see the ai-foundry-project module). Turning it back off
                                    forces a new resource.
      dynamic_throttling_enabled    Let Azure smooth spikes over the rate limit.
      fqdns                         Allowed FQDNs when outbound access is restricted.
      outbound_network_access_restricted  Restrict the account's own outbound calls.
      identity                      Managed identity. Default SystemAssigned.
      network_acls                  Public-endpoint firewall (only meaningful when public access is
                                    enabled). default_action defaults to Deny.
      network_injection             Inject the account into a delegated subnet (scenario + subnet_id).
      customer_managed_key          Encrypt with your own key vault key (identity_client_id optional).
      storage                       Attach a storage account (for kinds that use one).
      create_default_rai_policy     Build the hardened default RAI policy. null (default) means true
                                    for OpenAI / AIServices, false otherwise.
      default_rai_policy            Tuning for that default policy (severity, mode, prompt shields).
      rai_policies                  Extra custom RAI policies keyed by policy name.
      deployments                   Model deployments keyed by deployment name.
      qna_runtime_endpoint, custom_question_answering_*, metrics_advisor_*  Legacy kind passthroughs.
  EOT
  type = map(object({
    kind                               = optional(string, "AIServices")
    sku_name                           = optional(string, "S0")
    custom_subdomain_name              = optional(string)
    local_auth_enabled                 = optional(bool, false)
    public_network_access_enabled      = optional(bool, false)
    project_management_enabled         = optional(bool)
    dynamic_throttling_enabled         = optional(bool)
    fqdns                              = optional(list(string))
    outbound_network_access_restricted = optional(bool)

    metrics_advisor_aad_client_id                = optional(string)
    metrics_advisor_aad_tenant_id                = optional(string)
    metrics_advisor_super_user_name              = optional(string)
    metrics_advisor_website_name                 = optional(string)
    qna_runtime_endpoint                         = optional(string)
    custom_question_answering_search_service_id  = optional(string)
    custom_question_answering_search_service_key = optional(string)

    identity = optional(object({
      type         = optional(string, "SystemAssigned")
      identity_ids = optional(list(string))
    }), {})

    network_acls = optional(object({
      default_action = optional(string, "Deny")
      bypass         = optional(string)
      ip_rules       = optional(list(string), [])
      virtual_network_rules = optional(list(object({
        subnet_id                            = string
        ignore_missing_vnet_service_endpoint = optional(bool)
      })), [])
    }))

    network_injection = optional(object({
      scenario  = string
      subnet_id = string
    }))

    customer_managed_key = optional(object({
      key_vault_key_id   = string
      identity_client_id = optional(string)
    }))

    storage = optional(object({
      storage_account_id = string
      identity_client_id = optional(string)
    }))

    create_default_rai_policy = optional(bool)
    default_rai_policy = optional(object({
      name                  = optional(string)
      base_policy_name      = optional(string, "Microsoft.DefaultV2")
      mode                  = optional(string, "Blocking")
      severity_threshold    = optional(string, "Medium")
      enable_prompt_shields = optional(bool, true)
    }), {})

    rai_policies = optional(map(object({
      base_policy_name = optional(string, "Microsoft.DefaultV2")
      mode             = optional(string, "Blocking")
      tags             = optional(map(string))
      content_filters = list(object({
        name               = string
        source             = string
        filter_enabled     = optional(bool, true)
        block_enabled      = optional(bool, true)
        severity_threshold = optional(string, "Medium")
      }))
    })), {})

    deployments = optional(map(object({
      rai_policy_name            = optional(string)
      version_upgrade_option     = optional(string)
      dynamic_throttling_enabled = optional(bool)
      model = object({
        format  = optional(string, "OpenAI")
        name    = string
        version = optional(string)
      })
      sku = optional(object({
        name     = optional(string, "GlobalStandard")
        tier     = optional(string)
        size     = optional(string)
        family   = optional(string)
        capacity = optional(number, 1)
      }), {})
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for a in values(var.cognitive_accounts) : contains([
        "AIServices", "OpenAI", "FormRecognizer", "ContentSafety", "ComputerVision", "SpeechServices",
        "TextAnalytics", "TextTranslation", "Face", "CustomVision.Training", "CustomVision.Prediction",
        "HealthInsights", "ImmersiveReader", "MetricsAdvisor", "QnAMaker.v2", "CognitiveServices",
      ], a.kind)
    ])
    error_message = "Each cognitive_accounts[*].kind must be a supported Cognitive Services kind (for example AIServices, OpenAI, FormRecognizer, ContentSafety, SpeechServices)."
  }

  validation {
    condition = alltrue([
      for a in values(var.cognitive_accounts) :
      a.identity == null ? true : contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], a.identity.type)
    ])
    error_message = "identity.type must be SystemAssigned, UserAssigned, or \"SystemAssigned, UserAssigned\"."
  }

  validation {
    condition = alltrue([
      for a in values(var.cognitive_accounts) :
      a.network_acls == null ? true : contains(["Allow", "Deny"], a.network_acls.default_action)
    ])
    error_message = "network_acls.default_action must be Allow or Deny."
  }

  # network_acls.bypass is only accepted by the AI / multi-service kinds; FormRecognizer, Speech,
  # Vision, and others reject it. try() guards the deref (Terraform 1.9 evaluates both || operands).
  validation {
    condition = alltrue([
      for a in values(var.cognitive_accounts) :
      try(a.network_acls.bypass, null) == null || contains(["AIServices", "OpenAI", "CognitiveServices"], a.kind)
    ])
    error_message = "network_acls.bypass is only supported on AIServices, OpenAI, or CognitiveServices accounts; omit it for other kinds (for example FormRecognizer / Document Intelligence)."
  }

  validation {
    condition = alltrue([
      for a in values(var.cognitive_accounts) :
      contains(["Default", "Deferred", "Blocking", "Asynchronous_filter"], a.default_rai_policy.mode)
    ])
    error_message = "default_rai_policy.mode must be Default, Deferred, Blocking, or Asynchronous_filter."
  }

  validation {
    condition = alltrue([
      for a in values(var.cognitive_accounts) :
      contains(["Low", "Medium", "High"], a.default_rai_policy.severity_threshold)
    ])
    error_message = "default_rai_policy.severity_threshold must be Low, Medium, or High."
  }

  validation {
    condition = alltrue([
      for a in values(var.cognitive_accounts) :
      a.project_management_enabled != true || a.kind == "AIServices"
    ])
    error_message = "project_management_enabled is only supported when kind is AIServices."
  }

  validation {
    condition = alltrue(flatten([
      for a in values(var.cognitive_accounts) : [
        for d in values(a.deployments) : contains([
          "Standard", "GlobalStandard", "DataZoneStandard", "GlobalBatch", "DataZoneBatch",
          "ProvisionedManaged", "GlobalProvisionedManaged", "DataZoneProvisionedManaged",
        ], d.sku.name)
      ]
    ]))
    error_message = "Each deployment sku.name must be a valid Cognitive deployment SKU (for example GlobalStandard, Standard, DataZoneStandard)."
  }

  validation {
    condition = alltrue([
      for a in values(var.cognitive_accounts) :
      length(a.deployments) == 0 || contains(["OpenAI", "AIServices"], a.kind)
    ])
    error_message = "Model deployments are only valid on OpenAI or AIServices accounts; other kinds must have an empty deployments map."
  }
}

variable "location" {
  description = "Azure region for the cognitive accounts."
  type        = string
}

variable "resource_group_id" {
  description = "Resource id of the resource group to create the accounts in. The name and subscription are parsed from it (pass the rg module's ids output)."
  type        = string

  validation {
    condition     = try(provider::azurerm::parse_resource_id(var.resource_group_id).resource_type, "") == "resourceGroups"
    error_message = "resource_group_id must be a resource group id of the form /subscriptions/<sub>/resourceGroups/<name>."
  }
}

variable "tags" {
  description = "Tags to apply to the cognitive accounts and their RAI policies."
  type        = map(string)
  default     = {}
}
