locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  ais_name = "ais-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# Minimal call: one Azure AI Foundry (AIServices) account with the secure defaults, Entra-only auth,
# no public endpoint, a system-assigned identity, and a hardened default Responsible AI policy. No
# model deployment: the account is the smallest useful thing this module makes.
module "cognitive_account" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  cognitive_accounts = {
    (local.ais_name) = {
      kind = "AIServices"
    }
  }
}
