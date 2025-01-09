terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  # Extract number from VM size using regex
  # Matches numbers after any letter series (like D, DS, NP, L, etc.)
  # Handles cases like Standard_D2_v3, Standard_DS4_v2, Standard_NP20s, Standard_L48s_v3
  slots = can(regex("[A-Za-z]+[Ss]?(\\d+)", var.vm_size)) ? tonumber(regex("[A-Za-z]+[Ss]?(\\d+)", var.vm_size)[0]) : 1
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
    for_each = length(var.identity_ids) > 0 ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = var.identity_ids
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
      targetPoolSize = max(0, min($targetVMs, ${var.max_pool_size}));

      // For first interval deploy 1 node, for other intervals scale up/down as per tasks.
      $TargetDedicatedNodes = lifespan < interval ? 1 : targetPoolSize;
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
}
