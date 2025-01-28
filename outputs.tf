output "batch_pool_name" {
  description = "The name of the Azure Batch pool"
  value       = azurerm_batch_pool.pool.name
}

output "batch_pool_id" {
  description = "The ID of the Azure Batch pool"
  value       = azurerm_batch_pool.pool.id
}

output "managed_identity_client_id" {
  description = "The client ID of the managed identity"
  value       = data.azurerm_user_assigned_identity.mi.client_id
}

output "seqera_compute_env_id" {
  description = "The ID of the Tower compute environment"
  value       = var.create_seqera_compute_env ? restapi_object.seqera_compute_env[0].id : null
}
