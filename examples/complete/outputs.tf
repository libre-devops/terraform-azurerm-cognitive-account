output "account_ids" {
  description = "Map of account name to resource id."
  value       = module.cognitive_account.ids
}

output "deployment_ids" {
  description = "Map of \"<account>/<deployment>\" to deployment id."
  value       = module.cognitive_account.deployment_ids
}

output "endpoints" {
  description = "Map of account name to its endpoint."
  value       = module.cognitive_account.endpoints
}

output "rai_policy_ids" {
  description = "Map of RAI policy key to id (default policies by account name, custom by \"<account>/<policy>\")."
  value       = module.cognitive_account.rai_policy_ids
}
