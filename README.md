<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Cognitive Account

Azure Cognitive Services accounts (Azure AI Foundry, OpenAI, Document Intelligence, ...) with secure
defaults, model deployments, and a hardened Responsible AI policy built in.

[![CI](https://github.com/libre-devops/terraform-azurerm-cognitive-account/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-cognitive-account/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-cognitive-account?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-cognitive-account/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-cognitive-account)](./LICENSE)

---

## Overview

Azure Cognitive Services accounts keyed by name, secure by default. One entry provisions one account
of any `kind` (**AIServices** for the unified Azure AI Foundry resource, **OpenAI**, **FormRecognizer**
for Document Intelligence, **ContentSafety**, **SpeechServices**, ...), together with its **model
deployments** and **Responsible AI (RAI) policies**.

Secure defaults, all caller-overridable:

- **Entra-only auth**: `local_auth_enabled = false`, so the only credential is an Entra ID token
  (`DefaultAzureCredential`); grant data-plane roles (`Cognitive Services OpenAI User`) rather than
  handing out account keys.
- **No public endpoint**: `public_network_access_enabled = false`. Pair with a private endpoint (the
  `private-endpoint` module), or set it `true` with a deny-by-default `network_acls` allow-list.
- **System-assigned identity** and a **custom subdomain** (defaulted to the account name), both needed
  for token auth and for Azure AI Foundry project management.
- **A hardened default RAI policy** for OpenAI / AIServices accounts: Content Safety harm filters
  (Hate, Sexual, Violence, Self-harm) on both prompts and completions, plus **Prompt Shields**
  (Jailbreak and Indirect Attack / XPIA). It is attached to every deployment that does not name its
  own policy. Opt out per account with `create_default_rai_policy = false`, or supply your own via
  `rai_policies`.

For Azure AI Foundry, set `kind = "AIServices"` and `project_management_enabled = true`, then create
projects with the companion `ai-foundry-project` module. The resource group is passed by id and parsed.

> Model availability moves: models are deprecated and retired, and not every model is offered in every
> region or on every deployment SKU. Confirm what is current before pinning a version:
> `az cognitiveservices account list-models -n <account> -g <rg> -o table`.

## Usage

```hcl
module "cognitive_account" {
  source  = "libre-devops/cognitive-account/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-prd-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  cognitive_accounts = {
    "ais-ldo-uks-prd-001" = {
      kind                       = "AIServices"
      project_management_enabled = true

      deployments = {
        "gpt-4o-mini" = {
          model = { name = "gpt-4o-mini", version = "2024-07-18" }
          sku   = { name = "GlobalStandard", capacity = 10 }
        }
      }
    }
  }
}
```

Because keys are disabled, an OpenAI-compatible client authenticates with an Entra token and the
calling identity needs `Cognitive Services OpenAI User` on the account (grant it with the
`role-assignment` module).

## Examples

- [`examples/minimal`](./examples/minimal) - a single AIServices (Foundry) account with the secure
  defaults, no deployment.
- [`examples/complete`](./examples/complete) - an AIServices account with project management, a chat
  and an embedding deployment, an extra custom RAI policy, and the public endpoint flagged on behind a
  firewall; plus a Document Intelligence account. Both accounts' logs ship to a Log Analytics
  workspace via the `diagnostic-settings` module.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) (the
machine-applied source of truth, passed to Trivy with `--ignorefile`) and are mirrored in the table
below so the reason is auditable.

| Trivy ID | Resource | Finding | Justification |
|----------|----------|---------|---------------|
| _None_   |          |         |               |

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here. Where the finding is out of this module's
scope, point the justification at the Libre DevOps module that does address it (for example the
private-endpoint module). Both the file and this table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.47.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.47.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_cognitive_account.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_account) | resource |
| [azurerm_cognitive_account_rai_policy.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_account_rai_policy) | resource |
| [azurerm_cognitive_account_rai_policy.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_account_rai_policy) | resource |
| [azurerm_cognitive_deployment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cognitive_accounts"></a> [cognitive\_accounts](#input\_cognitive\_accounts) | Cognitive Services accounts to create, keyed by account name. One entry provisions one account<br/>(any kind: AIServices for Azure AI Foundry, OpenAI, FormRecognizer for Document Intelligence,<br/>ContentSafety, SpeechServices, ...) plus, optionally, its model deployments and Responsible AI<br/>(RAI) policies.<br/><br/>Secure defaults, all caller-overridable:<br/>  - local\_auth\_enabled = false          (Entra ID token auth only, account keys off)<br/>  - public\_network\_access\_enabled = false (not reachable over the public endpoint; pair with a<br/>                                          private endpoint, or set true with a network\_acls<br/>                                          allow-list)<br/>  - identity.type = SystemAssigned      (the account gets an Entra identity)<br/>  - custom\_subdomain\_name = <the account name> (required for Entra token auth and for Foundry<br/>                                          project management; must be globally unique)<br/>  - a hardened default RAI policy is built for OpenAI / AIServices accounts (Content Safety harm<br/>    filters on prompts and completions plus Prompt Shields) and attached to every deployment that<br/>    does not name its own policy. Set create\_default\_rai\_policy = false to opt out.<br/><br/>Per-account fields:<br/>  kind                          Account kind. Drives the naming prefix in the rego (oai-, ais-,<br/>                                docintel-, cog-). Defaults to AIServices (the unified Foundry<br/>                                resource).<br/>  sku\_name                      Account SKU. S0 is standard pay-as-you-go.<br/>  custom\_subdomain\_name         Globally unique subdomain. Defaults to the account name.<br/>  local\_auth\_enabled            Whether account keys work. Default false (Entra-only).<br/>  public\_network\_access\_enabled Public endpoint reachability. Default false.<br/>  project\_management\_enabled    AIServices only: enables Azure AI Foundry projects under this<br/>                                account (see the ai-foundry-project module). Turning it back off<br/>                                forces a new resource.<br/>  dynamic\_throttling\_enabled    Let Azure smooth spikes over the rate limit.<br/>  fqdns                         Allowed FQDNs when outbound access is restricted.<br/>  outbound\_network\_access\_restricted  Restrict the account's own outbound calls.<br/>  identity                      Managed identity. Default SystemAssigned.<br/>  network\_acls                  Public-endpoint firewall (only meaningful when public access is<br/>                                enabled). default\_action defaults to Deny.<br/>  network\_injection             Inject the account into a delegated subnet (scenario + subnet\_id).<br/>  customer\_managed\_key          Encrypt with your own key vault key (identity\_client\_id optional).<br/>  storage                       Attach a storage account (for kinds that use one).<br/>  create\_default\_rai\_policy     Build the hardened default RAI policy. null (default) means true<br/>                                for OpenAI / AIServices, false otherwise.<br/>  default\_rai\_policy            Tuning for that default policy (severity, mode, prompt shields).<br/>  rai\_policies                  Extra custom RAI policies keyed by policy name.<br/>  deployments                   Model deployments keyed by deployment name.<br/>  qna\_runtime\_endpoint, custom\_question\_answering\_*, metrics\_advisor\_*  Legacy kind passthroughs. | <pre>map(object({<br/>    kind                               = optional(string, "AIServices")<br/>    sku_name                           = optional(string, "S0")<br/>    custom_subdomain_name              = optional(string)<br/>    local_auth_enabled                 = optional(bool, false)<br/>    public_network_access_enabled      = optional(bool, false)<br/>    project_management_enabled         = optional(bool)<br/>    dynamic_throttling_enabled         = optional(bool)<br/>    fqdns                              = optional(list(string))<br/>    outbound_network_access_restricted = optional(bool)<br/><br/>    metrics_advisor_aad_client_id                = optional(string)<br/>    metrics_advisor_aad_tenant_id                = optional(string)<br/>    metrics_advisor_super_user_name              = optional(string)<br/>    metrics_advisor_website_name                 = optional(string)<br/>    qna_runtime_endpoint                         = optional(string)<br/>    custom_question_answering_search_service_id  = optional(string)<br/>    custom_question_answering_search_service_key = optional(string)<br/><br/>    identity = optional(object({<br/>      type         = optional(string, "SystemAssigned")<br/>      identity_ids = optional(list(string))<br/>    }), {})<br/><br/>    network_acls = optional(object({<br/>      default_action = optional(string, "Deny")<br/>      bypass         = optional(string)<br/>      ip_rules       = optional(list(string), [])<br/>      virtual_network_rules = optional(list(object({<br/>        subnet_id                            = string<br/>        ignore_missing_vnet_service_endpoint = optional(bool)<br/>      })), [])<br/>    }))<br/><br/>    network_injection = optional(object({<br/>      scenario  = string<br/>      subnet_id = string<br/>    }))<br/><br/>    customer_managed_key = optional(object({<br/>      key_vault_key_id   = string<br/>      identity_client_id = optional(string)<br/>    }))<br/><br/>    storage = optional(object({<br/>      storage_account_id = string<br/>      identity_client_id = optional(string)<br/>    }))<br/><br/>    create_default_rai_policy = optional(bool)<br/>    default_rai_policy = optional(object({<br/>      name                  = optional(string)<br/>      base_policy_name      = optional(string, "Microsoft.DefaultV2")<br/>      mode                  = optional(string, "Blocking")<br/>      severity_threshold    = optional(string, "Medium")<br/>      enable_prompt_shields = optional(bool, true)<br/>    }), {})<br/><br/>    rai_policies = optional(map(object({<br/>      base_policy_name = optional(string, "Microsoft.DefaultV2")<br/>      mode             = optional(string, "Blocking")<br/>      tags             = optional(map(string))<br/>      content_filters = list(object({<br/>        name               = string<br/>        source             = string<br/>        filter_enabled     = optional(bool, true)<br/>        block_enabled      = optional(bool, true)<br/>        severity_threshold = optional(string, "Medium")<br/>      }))<br/>    })), {})<br/><br/>    deployments = optional(map(object({<br/>      rai_policy_name            = optional(string)<br/>      version_upgrade_option     = optional(string)<br/>      dynamic_throttling_enabled = optional(bool)<br/>      model = object({<br/>        format  = optional(string, "OpenAI")<br/>        name    = string<br/>        version = optional(string)<br/>      })<br/>      sku = optional(object({<br/>        name     = optional(string, "GlobalStandard")<br/>        tier     = optional(string)<br/>        size     = optional(string)<br/>        family   = optional(string)<br/>        capacity = optional(number, 1)<br/>      }), {})<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the cognitive accounts. | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Resource id of the resource group to create the accounts in. The name and subscription are parsed from it (pass the rg module's ids output). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the cognitive accounts and their RAI policies. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_custom_subdomain_names"></a> [custom\_subdomain\_names](#output\_custom\_subdomain\_names) | Map of account name to its custom subdomain. |
| <a name="output_deployment_ids"></a> [deployment\_ids](#output\_deployment\_ids) | Map of "<account>/<deployment>" to the deployment resource id. |
| <a name="output_deployment_ids_zipmap"></a> [deployment\_ids\_zipmap](#output\_deployment\_ids\_zipmap) | Map of "<account>/<deployment>" to a { name, id } object. |
| <a name="output_endpoints"></a> [endpoints](#output\_endpoints) | Map of account name to its (OpenAI-compatible) endpoint. |
| <a name="output_identities"></a> [identities](#output\_identities) | Map of account name to its managed identity { principal\_id, tenant\_id } (principal\_id is populated for system-assigned identities). |
| <a name="output_ids"></a> [ids](#output\_ids) | Map of account name to its resource id. |
| <a name="output_ids_zipmap"></a> [ids\_zipmap](#output\_ids\_zipmap) | Map of account name to a { name, id } object, for passing where both are needed together. |
| <a name="output_names"></a> [names](#output\_names) | The account names. |
| <a name="output_primary_access_keys"></a> [primary\_access\_keys](#output\_primary\_access\_keys) | Map of account name to its primary access key (empty when local\_auth\_enabled is false). Prefer Entra ID token auth. |
| <a name="output_rai_policy_ids"></a> [rai\_policy\_ids](#output\_rai\_policy\_ids) | Map of RAI policy key to its id: default policies keyed by account name, custom policies keyed by "<account>/<policy>". |
| <a name="output_rai_policy_names"></a> [rai\_policy\_names](#output\_rai\_policy\_names) | Map of account name to the name of its default RAI policy (only for accounts that build one). |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Resource group name parsed from resource\_group\_id. |
| <a name="output_secondary_access_keys"></a> [secondary\_access\_keys](#output\_secondary\_access\_keys) | Map of account name to its secondary access key (empty when local\_auth\_enabled is false). |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Subscription id parsed from resource\_group\_id. |
| <a name="output_tags"></a> [tags](#output\_tags) | The tags applied to the accounts. |
<!-- END_TF_DOCS -->
