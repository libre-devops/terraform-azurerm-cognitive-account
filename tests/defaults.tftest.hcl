# Plan-time tests for the module. The azurerm provider is mocked, so no credentials, no
# features block, and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  location          = "uksouth"
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01"

  cognitive_accounts = {
    "ais-ldo-uks-tst-01" = {
      deployments = {
        "gpt" = {
          model = { name = "gpt-4.1-mini", version = "2025-04-14" }
        }
      }
    }
  }
}

# The defaults are secure: a Foundry (AIServices) account with Entra-only auth, no public endpoint,
# a system-assigned identity, a custom subdomain derived from the name, a hardened default RAI policy
# of ten filters (eight harm plus two Prompt Shields), and a deployment bound to that policy.
run "creates_secure_foundry_account" {
  command = plan

  assert {
    condition     = azurerm_cognitive_account.this["ais-ldo-uks-tst-01"].kind == "AIServices"
    error_message = "Default account kind should be AIServices (the unified Foundry resource)."
  }

  assert {
    condition     = azurerm_cognitive_account.this["ais-ldo-uks-tst-01"].local_auth_enabled == false
    error_message = "Accounts must be Entra-only (account keys disabled) by default."
  }

  assert {
    condition     = azurerm_cognitive_account.this["ais-ldo-uks-tst-01"].public_network_access_enabled == false
    error_message = "The public endpoint must be disabled by default."
  }

  assert {
    condition     = azurerm_cognitive_account.this["ais-ldo-uks-tst-01"].custom_subdomain_name == "ais-ldo-uks-tst-01"
    error_message = "custom_subdomain_name should default to the account name."
  }

  assert {
    condition     = azurerm_cognitive_account.this["ais-ldo-uks-tst-01"].identity[0].type == "SystemAssigned"
    error_message = "The account should get a system-assigned identity by default."
  }

  assert {
    condition     = length(azurerm_cognitive_account_rai_policy.default) == 1
    error_message = "A default RAI policy should be built for an AIServices account."
  }

  # Four harm categories times two directions (8), plus the two Prompt Shields (10).
  assert {
    condition     = length(azurerm_cognitive_account_rai_policy.default["ais-ldo-uks-tst-01"].content_filter) == 10
    error_message = "The default RAI policy should carry the eight harm filters and both Prompt Shields."
  }

  assert {
    condition     = anytrue([for f in azurerm_cognitive_account_rai_policy.default["ais-ldo-uks-tst-01"].content_filter : f.name == "Indirect Attack"])
    error_message = "The Indirect Attack (XPIA) Prompt Shield must be present by default."
  }

  assert {
    condition     = azurerm_cognitive_deployment.this["ais-ldo-uks-tst-01/gpt"].rai_policy_name == "ais-ldo-uks-tst-01-rai"
    error_message = "A deployment with no explicit policy should bind to the account's default RAI policy."
  }

  assert {
    condition     = azurerm_cognitive_deployment.this["ais-ldo-uks-tst-01/gpt"].sku[0].name == "GlobalStandard"
    error_message = "Deployments should default to the GlobalStandard (consumption) SKU."
  }
}

# Prompt Shields can be turned off, leaving only the eight harm-category filters.
run "prompt_shields_can_be_disabled" {
  command = plan

  variables {
    cognitive_accounts = {
      "ais-ldo-uks-tst-01" = {
        default_rai_policy = { enable_prompt_shields = false }
      }
    }
  }

  assert {
    condition     = length(azurerm_cognitive_account_rai_policy.default["ais-ldo-uks-tst-01"].content_filter) == 8
    error_message = "Disabling Prompt Shields should leave only the eight harm-category filters."
  }
}

# The default policy can be opted out entirely; deployments then carry no RAI policy name.
run "default_rai_policy_can_be_opted_out" {
  command = plan

  variables {
    cognitive_accounts = {
      "ais-ldo-uks-tst-01" = {
        create_default_rai_policy = false
        deployments = {
          "gpt" = { model = { name = "gpt-4.1-mini" } }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_cognitive_account_rai_policy.default) == 0
    error_message = "create_default_rai_policy = false should build no default policy."
  }

  assert {
    condition     = length(azurerm_cognitive_deployment.this) == 1
    error_message = "The deployment should still be created when the default RAI policy is opted out."
  }
}

# A custom RAI policy is created and keyed as "<account>/<policy>".
run "custom_rai_policy_is_created" {
  command = plan

  variables {
    cognitive_accounts = {
      "ais-ldo-uks-tst-01" = {
        rai_policies = {
          "strict" = {
            content_filters = [
              { name = "Hate", source = "Prompt" },
              { name = "Hate", source = "Completion" },
            ]
          }
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_cognitive_account_rai_policy.custom["ais-ldo-uks-tst-01/strict"].content_filter) == 2
    error_message = "A custom RAI policy should be created with its supplied content filters."
  }
}

# A non-AIServices, non-OpenAI account (Document Intelligence) gets no default RAI policy.
run "document_intelligence_has_no_rai_policy" {
  command = plan

  variables {
    cognitive_accounts = {
      "docintel-ldo-uks-tst-01" = {
        kind = "FormRecognizer"
      }
    }
  }

  assert {
    condition     = length(azurerm_cognitive_account_rai_policy.default) == 0
    error_message = "RAI policies apply only to OpenAI / AIServices; FormRecognizer should get none."
  }
}

# Validation: an unsupported kind is rejected.
run "rejects_invalid_kind" {
  command = plan

  variables {
    cognitive_accounts = {
      "bad" = { kind = "NotARealKind" }
    }
  }

  expect_failures = [var.cognitive_accounts]
}

# Validation: deployments are only valid on OpenAI / AIServices accounts.
run "rejects_deployment_on_speech_account" {
  command = plan

  variables {
    cognitive_accounts = {
      "speech" = {
        kind = "SpeechServices"
        deployments = {
          "gpt" = { model = { name = "gpt-4.1-mini" } }
        }
      }
    }
  }

  expect_failures = [var.cognitive_accounts]
}

# Validation: network_acls.bypass is rejected on kinds that do not support it (FormRecognizer).
run "rejects_bypass_on_form_recognizer" {
  command = plan

  variables {
    cognitive_accounts = {
      "docintel-ldo-uks-tst-01" = {
        kind         = "FormRecognizer"
        network_acls = { default_action = "Deny", bypass = "AzureServices" }
      }
    }
  }

  expect_failures = [var.cognitive_accounts]
}

# Validation: project management is only supported on AIServices accounts.
run "rejects_project_management_on_openai" {
  command = plan

  variables {
    cognitive_accounts = {
      "oai-ldo-uks-tst-01" = {
        kind                       = "OpenAI"
        project_management_enabled = true
      }
    }
  }

  expect_failures = [var.cognitive_accounts]
}
