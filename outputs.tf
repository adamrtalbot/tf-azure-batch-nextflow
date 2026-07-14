output "batch_pool_name" {
  description = "The name of the Azure Batch pool"
  value       = azurerm_batch_pool.pool.name
}

output "batch_pool_id" {
  description = "The ID of the Azure Batch pool"
  value       = azurerm_batch_pool.pool.id
}

output "worker_pool_name" {
  description = "The name of the worker Azure Batch pool (null unless dual pool mode is enabled)"
  value       = var.enable_dual_pool ? azurerm_batch_pool.worker[0].name : null
}

output "worker_pool_id" {
  description = "The ID of the worker Azure Batch pool (null unless dual pool mode is enabled)"
  value       = var.enable_dual_pool ? azurerm_batch_pool.worker[0].id : null
}

output "worker_managed_identity_client_id" {
  description = "The client ID of the managed identity used by the worker pool (null unless dual pool mode is enabled)"
  value       = var.enable_dual_pool ? local.worker_identity_client_id : null
}

output "managed_identity_client_id" {
  description = "The client ID of the managed identity"
  value       = data.azurerm_user_assigned_identity.mi.client_id
}

output "credentials_id" {
  description = "The ID of the credentials"
  value       = local.credentials_id
}

output "seqera_compute_env_id" {
  description = "The ID of the Seqera compute environment"
  value       = var.create_seqera_compute_env ? seqera_compute_env.azure_batch[0].compute_env_id : null
}



