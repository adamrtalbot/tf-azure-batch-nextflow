terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.18"
    }
  }
}

provider "azurerm" {
  features {}
}

# Add provider configuration for REST API
provider "restapi" {
  insecure = true
  uri      = trimsuffix(var.seqera_api_endpoint, "/")
  headers = {
    "Authorization" = var.seqera_access_token == null ? "" : "Bearer ${var.seqera_access_token}"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
  }
  write_returns_object  = true
  create_returns_object = true
}

# Get credentials by name
data "restapi_object" "credentials" {
  count        = var.create_seqera_compute_env ? 1 : 0
  path         = "/credentials"
  search_key   = "name"
  search_value = var.seqera_credentials_name
  query_string = "workspaceId=${var.seqera_workspace_id}"
  results_key  = "credentials"
}

locals {
  # Extract number from VM size using regex
  # Matches numbers after any letter series (like D, DS, NP, L, etc.)
  # Handles cases like Standard_D2_v3, Standard_DS4_v2, Standard_NP20s, Standard_L48s_v3
  slots            = can(regex("[A-Za-z]+[Ss]?(\\d+)", var.vm_size)) ? tonumber(regex("[A-Za-z]+[Ss]?(\\d+)", var.vm_size)[0]) : 1
  compute_env_name = coalesce(var.seqera_compute_env_name, var.batch_pool_name)
  # Only try to access credentials when create_seqera_compute_env is true
  credentials_id = var.create_seqera_compute_env ? jsondecode(data.restapi_object.credentials[0].api_response).credentials.id : null
}

resource "terraform_data" "credentials_id" {
  input = local.credentials_id
}

resource "terraform_data" "compute_env_name" {
  input = local.compute_env_name
}

resource "terraform_data" "managed_identity_id" {
  input = data.azurerm_user_assigned_identity.mi.id
}

resource "terraform_data" "pre_run_script" {
  input = var.seqera_pre_run_script
}

resource "terraform_data" "post_run_script" {
  input = var.seqera_post_run_script
}

resource "terraform_data" "nextflow_config" {
  input = var.seqera_nextflow_config
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
        registry_server = container_registries.value.registry_server
        user_name       = container_registries.value.user_name
        password        = container_registries.value.password
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
    command_line     = "bash -c \"chmod +x azcopy && mkdir $AZ_BATCH_NODE_SHARED_DIR/bin/ && cp azcopy $AZ_BATCH_NODE_SHARED_DIR/bin/\""
    wait_for_success = true

    task_retry_maximum = 0

    user_identity {
      auto_user {
        elevation_level = "NonAdmin"
        scope           = "Pool"
      }
    }

    resource_file {
      http_url  = var.azcopy_url
      file_path = "azcopy"
    }
  }

  lifecycle {
    ignore_changes = [
      start_task["task_retry_maximum"]
    ]
  }
}

# Replace null_resource with restapi_object
resource "restapi_object" "seqera_compute_env" {
  count          = var.create_seqera_compute_env ? 1 : 0
  path           = "/compute-envs"
  query_string   = "workspaceId=${var.seqera_workspace_id}"
  create_method  = "POST"
  id_attribute   = "computeEnvId"
  destroy_method = "DELETE"

  data = jsonencode({
    computeEnv = {
      credentialsId = local.credentials_id
      name          = local.compute_env_name
      platform      = "azure-batch"
      config = {
        workDir                 = var.seqera_work_dir
        region                  = data.azurerm_resource_group.rg.location
        headPool                = var.batch_pool_name
        managedIdentityClientId = data.azurerm_user_assigned_identity.mi.client_id
        preRunScript            = terraform_data.pre_run_script.output
        postRunScript           = terraform_data.post_run_script.output
        nextflowConfig          = terraform_data.nextflow_config.output
      }
    }
  })

  depends_on = [
    azurerm_batch_pool.pool,
    terraform_data.pre_run_script,
    terraform_data.post_run_script,
    terraform_data.nextflow_config
  ]

  lifecycle {
    replace_triggered_by = [
      terraform_data.credentials_id.output,
      terraform_data.compute_env_name.output,
      terraform_data.managed_identity_id.output,
      terraform_data.pre_run_script.output,
      terraform_data.post_run_script.output,
      terraform_data.nextflow_config.output
    ]
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
