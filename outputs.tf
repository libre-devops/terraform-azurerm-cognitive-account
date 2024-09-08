output "cognitive_account_endpoints" {
  description = "The endpoints of the Cognitive Service Accounts."
  value       = { for key, acc in azurerm_cognitive_account.accounts : key => acc.endpoint }
}

output "cognitive_account_identities" {
  description = "The identity blocks for the Cognitive Service Accounts, including principal_id and tenant_id."
  value = {
    for key, acc in azurerm_cognitive_account.accounts : key => {
      principal_id = acc.identity[0].principal_id
      tenant_id    = acc.identity[0].tenant_id
    }
  }
}

output "cognitive_account_ids" {
  description = "The IDs of the Cognitive Service Accounts."
  value       = { for key, acc in azurerm_cognitive_account.accounts : key => acc.id }
}

output "cognitive_account_primary_access_keys" {
  description = "The primary access keys for the Cognitive Service Accounts."
  value       = { for key, acc in azurerm_cognitive_account.accounts : key => acc.primary_access_key }
}

output "cognitive_account_secondary_access_keys" {
  description = "The secondary access keys for the Cognitive Service Accounts."
  value       = { for key, acc in azurerm_cognitive_account.accounts : key => acc.secondary_access_key }
}
