terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    seqera = {
      source  = "seqeralabs/seqera"
      version = "~> 0.26"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "seqera" {
  server_url  = trimsuffix(var.seqera_api_endpoint, "/")
  bearer_auth = var.seqera_access_token
}

# Get credentials by name using seqera_credentials data source
data "seqera_credentials" "workspace_credentials" {
  count        = var.create_seqera_compute_env ? 1 : 0
  workspace_id = var.seqera_workspace_id
}

locals {
  # Extract number from VM size using regex
  # Matches numbers after any letter series (like D, DS, NP, L, etc.)
  # Handles cases like Standard_D2_v3, Standard_DS4_v2, Standard_NP20s, Standard_L48s_v3
  slots            = can(regex("[A-Za-z]+[Ss]?(\\d+)", var.vm_size)) ? tonumber(regex("[A-Za-z]+[Ss]?(\\d+)", var.vm_size)[0]) : 1
  compute_env_name = coalesce(var.seqera_compute_env_name, var.batch_pool_name)

  # Create a map of credentials indexed by name for easy lookup
  credentials_map = var.create_seqera_compute_env ? {
    for cred in data.seqera_credentials.workspace_credentials[0].credentials : cred.name => cred
  } : {}

  # Look up the credential ID by name
  credentials_id = var.create_seqera_compute_env && var.seqera_credentials_name != null ? lookup(local.credentials_map, var.seqera_credentials_name, null).id : null
}

# Batch pool
resource "azurerm_batch_pool" "pool" {
  name                = var.batch_pool_name
  resource_group_name = var.resource_group_name
  account_name        = var.batch_account_name
  display_name        = "Seqera Compute Pool"
  vm_size             = var.vm_size
  node_agent_sku_id   = var.node_agent_sku_id
  max_tasks_per_node  = local.slots

  # Add network configuration only if subnet_id is provided
  dynamic "network_configuration" {
    for_each = var.subnet_id != null ? [1] : []
    content {
      subnet_id = var.subnet_id
    }
  }

  dynamic "identity" {
    for_each = var.managed_identity_name != "" ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [data.azurerm_user_assigned_identity.mi.id]
    }
  }

  storage_image_reference {
    publisher = var.vm_image_publisher
    offer     = var.vm_image_offer
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }

  # Container configuration for Docker support
  container_configuration {
    type = "DockerCompatible"
    dynamic "container_registries" {
      for_each = var.container_registries
      content {
        registry_server           = container_registries.value.registry_server
        user_name                 = container_registries.value.user_name != null ? container_registries.value.user_name : null
        password                  = container_registries.value.password != null ? container_registries.value.password : null
        user_assigned_identity_id = container_registries.value.identity_id != null ? container_registries.value.identity_id : (container_registries.value.use_managed_identity ? data.azurerm_user_assigned_identity.mi.id : null)
      }
    }
  }

  # Auto-scale configuration
  auto_scale {
    evaluation_interval = "PT5M"
    formula             = <<EOF
      // Get pool lifetime since creation.
      lifespan = time() - time("2024-10-30T00:00:00.880011Z");
      interval = TimeInterval_Minute * 5;

      // Compute the target nodes based on pending tasks.
      // $PendingTasks == The sum of $ActiveTasks and $RunningTasks
      $samples = $PendingTasks.GetSamplePercent(interval);
      $tasks = $samples < 70 ? max(0, $PendingTasks.GetSample(1)) : max($PendingTasks.GetSample(1), avg($PendingTasks.GetSample(interval)));
      $targetVMs = $tasks > 0 ? $tasks : max(0, $TargetDedicatedNodes/2);
      targetPoolSize = max(${var.min_pool_size}, min($targetVMs, ${var.max_pool_size}));

      // For first interval deploy min_pool_size node, for other intervals scale up/down as per tasks.
      $TargetDedicatedNodes = lifespan < interval ? ${var.min_pool_size} : targetPoolSize;
      $NodeDeallocationOption = taskcompletion;
    EOF
  }

  # Start task to install azcopy
  start_task {
    command_line     = var.start_task_command_line
    wait_for_success = true

    task_retry_maximum = 0

    user_identity {
      auto_user {
        elevation_level = var.start_task_elevation_level
        scope           = var.start_task_scope
      }
    }

    dynamic "resource_file" {
      for_each = var.start_task_resource_files
      content {
        http_url  = resource_file.value.url
        file_path = resource_file.value.file_path
      }
    }
  }
}

# Seqera Platform compute environment
resource "seqera_compute_env" "azure_batch" {
  count        = var.create_seqera_compute_env ? 1 : 0
  workspace_id = var.seqera_workspace_id

  compute_env = {
    name           = local.compute_env_name
    platform       = "azure-batch"
    credentials_id = local.credentials_id

    config = {
      azure_batch = {
        region                     = data.azurerm_resource_group.rg.location
        work_dir                   = var.seqera_work_dir
        head_pool                  = azurerm_batch_pool.pool.name
        managed_identity_client_id = data.azurerm_user_assigned_identity.mi.client_id
        pre_run_script             = var.seqera_pre_run_script
        post_run_script            = var.seqera_post_run_script
        nextflow_config            = var.seqera_nextflow_config
      }
    }
  }
}

# Add data source to get resource group location
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Get managed identity details
data "azurerm_user_assigned_identity" "mi" {
  name                = var.managed_identity_name
  resource_group_name = var.managed_identity_resource_group
}
