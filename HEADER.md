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
        "gpt-5-mini" = {
          model = { name = "gpt-5-mini", version = "2025-08-07" }
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
