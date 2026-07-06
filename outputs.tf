output "custom_subdomain_names" {
  description = "Map of account name to its custom subdomain."
  value       = { for k, v in azurerm_cognitive_account.this : k => v.custom_subdomain_name }
}

output "deployment_ids" {
  description = "Map of \"<account>/<deployment>\" to the deployment resource id."
  value       = { for k, v in azurerm_cognitive_deployment.this : k => v.id }
}

output "deployment_ids_zipmap" {
  description = "Map of \"<account>/<deployment>\" to a { name, id } object."
  value       = { for k, v in azurerm_cognitive_deployment.this : k => { name = v.name, id = v.id } }
}

output "endpoints" {
  description = "Map of account name to its (OpenAI-compatible) endpoint."
  value       = { for k, v in azurerm_cognitive_account.this : k => v.endpoint }
}

output "identities" {
  description = "Map of account name to its managed identity { principal_id, tenant_id } (principal_id is populated for system-assigned identities)."
  value = {
    for k, v in azurerm_cognitive_account.this : k => try({
      principal_id = v.identity[0].principal_id
      tenant_id    = v.identity[0].tenant_id
    }, null)
  }
}

output "ids" {
  description = "Map of account name to its resource id. Consumers building child resources from these ids (for example AI Foundry projects) are ordered after the account's own children too, see the depends_on note below."
  value       = { for k, v in azurerm_cognitive_account.this : k => v.id }

  # The Cognitive Services RP allows one mutation per account at a time, so a consumer child
  # resource (for example an AI Foundry project passed this id) deleting in parallel with this
  # module's RAI policies or deployments fails with 409 RequestConflict. Carrying the account
  # children on the id outputs orders every consumer after them: created once the account is fully
  # configured, destroyed before the children are removed. The map keys stay plan-known, so
  # consumer for_each over this output still works.
  depends_on = [
    azurerm_cognitive_account_rai_policy.default,
    azurerm_cognitive_account_rai_policy.custom,
    azurerm_cognitive_deployment.this,
  ]
}

output "ids_zipmap" {
  description = "Map of account name to a { name, id } object, for passing where both are needed together. Carries the same child-resource ordering as ids."
  value       = { for k, v in azurerm_cognitive_account.this : k => { name = v.name, id = v.id } }

  # Same ordering guarantee as ids, see the note there.
  depends_on = [
    azurerm_cognitive_account_rai_policy.default,
    azurerm_cognitive_account_rai_policy.custom,
    azurerm_cognitive_deployment.this,
  ]
}

output "names" {
  description = "The account names."
  value       = keys(azurerm_cognitive_account.this)
}

output "primary_access_keys" {
  description = "Map of account name to its primary access key (empty when local_auth_enabled is false). Prefer Entra ID token auth."
  value       = { for k, v in azurerm_cognitive_account.this : k => v.primary_access_key }
  sensitive   = true
}

output "rai_policy_ids" {
  description = "Map of RAI policy key to its id: default policies keyed by account name, custom policies keyed by \"<account>/<policy>\"."
  value = merge(
    { for k, v in azurerm_cognitive_account_rai_policy.default : k => v.id },
    { for k, v in azurerm_cognitive_account_rai_policy.custom : k => v.id },
  )
}

output "rai_policy_names" {
  description = "Map of account name to the name of its default RAI policy (only for accounts that build one)."
  value       = { for k, v in azurerm_cognitive_account_rai_policy.default : k => v.name }
}

output "resource_group_name" {
  description = "Resource group name parsed from resource_group_id."
  value       = local.resource_group_name
}

output "secondary_access_keys" {
  description = "Map of account name to its secondary access key (empty when local_auth_enabled is false)."
  value       = { for k, v in azurerm_cognitive_account.this : k => v.secondary_access_key }
  sensitive   = true
}

output "subscription_id" {
  description = "Subscription id parsed from resource_group_id."
  value       = local.rg.subscription_id
}

output "tags" {
  description = "The tags applied to the accounts."
  value       = var.tags
}
