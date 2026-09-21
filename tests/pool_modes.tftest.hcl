mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      location = "eastus"
    }
  }

  mock_data "azurerm_user_assigned_identity" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/nextflow-id"
      client_id = "00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "seqera" {}

variables {
  resource_group_name             = "rg"
  batch_account_name              = "batch"
  batch_pool_name                 = "head"
  max_pool_size                   = 8
  worker_max_pool_size            = 8
  managed_identity_resource_group = "rg"
  create_seqera_compute_env       = true
  seqera_workspace_id             = 1
  seqera_work_dir                 = "az://work"
  seqera_credentials_id           = "credential-id"
}

run "manual_single_pool" {
  command = plan

  assert {
    condition     = length(azurerm_batch_pool.pool) == 1
    error_message = "Manual mode must create the head pool."
  }

  assert {
    condition     = length(azurerm_batch_pool.worker) == 0
    error_message = "Single-pool mode must not create a worker pool."
  }

  assert {
    condition     = seqera_compute_env.azure_batch[0].compute_env.config.azure_batch.head_pool == "head"
    error_message = "Manual mode must send the Terraform-managed head pool name to Platform."
  }

  assert {
    condition     = local.azure_batch_config.forge == null && local.azure_batch_config.managed_identity_head_resource_id == null && local.azure_batch_config.managed_identity_pool_resource_id == null
    error_message = "Manual mode must omit Forge and managed identity resource IDs."
  }
}

run "manual_dual_pool" {
  command = plan

  variables {
    enable_dual_pool             = true
    worker_managed_identity_name = "nextflow-worker-id"
  }

  assert {
    condition     = length(azurerm_batch_pool.pool) == 1 && length(azurerm_batch_pool.worker) == 1
    error_message = "Manual dual-pool mode must create both AzureRM pools."
  }


  assert {
    condition     = seqera_compute_env.azure_batch[0].compute_env.config.azure_batch.worker_pool == "head-worker"
    error_message = "Manual dual-pool mode must send the worker pool name to Platform."
  }


  assert {
    condition     = local.azure_batch_config.managed_identity_pool_client_id != null && local.azure_batch_config.managed_identity_head_resource_id == null && local.azure_batch_config.managed_identity_pool_resource_id == null
    error_message = "Manual dual-pool mode must send the worker client ID without Forge-only resource IDs."
  }
}

run "forge_single_pool" {
  command = plan

  variables {
    enable_batch_forge = true
  }

  assert {
    condition     = length(azurerm_batch_pool.pool) == 0 && length(azurerm_batch_pool.worker) == 0
    error_message = "Batch Forge mode must not create AzureRM pools."
  }

  assert {
    condition     = seqera_compute_env.azure_batch[0].compute_env.config.azure_batch.forge.vm_count == 8
    error_message = "Single-pool Forge mode must send max_pool_size to Platform."
  }

  assert {
    condition     = seqera_compute_env.azure_batch[0].compute_env.config.azure_batch.managed_identity_head_resource_id != null
    error_message = "Forge mode must send the managed identity resource ID used for pool creation."
  }


  assert {
    condition     = local.azure_batch_config.head_pool == null && local.azure_batch_config.worker_pool == null
    error_message = "Forge mode must omit manual pool names."
  }
}

run "forge_dual_pool" {
  command = plan

  variables {
    enable_batch_forge           = true
    enable_dual_pool             = true
    worker_managed_identity_name = "nextflow-worker-id"
  }

  assert {
    condition     = length(azurerm_batch_pool.pool) == 0 && length(azurerm_batch_pool.worker) == 0
    error_message = "Dual-pool Forge mode must leave pool creation to Seqera Platform."
  }

  assert {
    condition     = seqera_compute_env.azure_batch[0].compute_env.config.azure_batch.forge.head_pool.vm_count == 8 && seqera_compute_env.azure_batch[0].compute_env.config.azure_batch.forge.worker_pool.vm_count == 8
    error_message = "Dual-pool Forge mode must send both pool configurations to Platform."
  }

  assert {
    condition     = seqera_compute_env.azure_batch[0].compute_env.config.azure_batch.managed_identity_pool_resource_id != null
    error_message = "Dual-pool Forge mode must send the worker identity resource ID."
  }
}

run "forge_requires_compute_environment" {
  command = plan

  variables {
    enable_batch_forge        = true
    create_seqera_compute_env = false
  }

  expect_failures = [var.enable_batch_forge]
}
