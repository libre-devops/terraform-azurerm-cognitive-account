output "account_ids" {
  description = "Map of account name to resource id."
  value       = module.cognitive_account.ids
}

output "endpoints" {
  description = "Map of account name to its endpoint."
  value       = module.cognitive_account.endpoints
}

output "rai_policy_names" {
  description = "Map of account name to its default RAI policy name."
  value       = module.cognitive_account.rai_policy_names
}
