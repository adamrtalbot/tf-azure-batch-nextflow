output "batch_pool_name" {
  description = "The name of the Azure Batch pool"
  value       = azurerm_batch_pool.pool.name
}

output "batch_pool_id" {
  description = "The ID of the Azure Batch pool"
  value       = azurerm_batch_pool.pool.id
}
