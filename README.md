# Azure Batch Pool for Nextflow

This Terraform configuration creates an Azure Batch pool optimized for running Nextflow workflows. The pool is configured with Ubuntu containers and includes the necessary tools for Nextflow execution.

## Description

This module creates an Azure Batch pool with:

- Docker-compatible nodes (Ubuntu 20.04 LTS by default)
- Automatic scaling based on pending tasks with a 5-minute evaluation interval
- Maximum tasks per node set to match the VM's CPU core count
- Pre-installed azcopy for efficient data transfer using the startTask
- Auto-scaling formula that:
  - Deploys 1 node initially
  - Scales based on pending tasks
  - Scales down to 50% when idle
  - Respects maximum pool size limit

## Usage

Create a `terraform.tfvars` file with your configuration:

```terraform
# Required Azure details
resource_group_name = "my_resource_group"
batch_account_name = "mybatchaccount"

# Required Batch Pool details
batch_pool_name = "mypool"
vm_size = "Standard_E2d_v5"
max_pool_size = 2

# Required VM image configuration
vm_image_publisher = "microsoft-azure-batch"
vm_image_offer = "ubuntu-server-container"
vm_image_sku = "20-04-lts"
vm_image_version = "latest"
node_agent_sku_id = "batch.node.ubuntu 20.04"

# Optional AzCopy configuration (default value shown)
azcopy_url = "https://nf-xpack.seqera.io/azcopy/linux_amd64_10.8.0/azcopy"

# Optional networking configuration
subnet_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.Network/virtualNetworks/<vnet_name>/subnets/<subnet_name>"

# Optional managed identity configuration
identity_ids = ["/subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity_name>"]
```

Run `terraform init` and `terraform apply` to create the Batch pool. You should see the pool created in the Azure portal.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.117.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_batch_pool.pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/batch_pool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azcopy_url"></a> [azcopy\_url](#input\_azcopy\_url) | URL to download azcopy binary | `string` | `"https://nf-xpack.seqera.io/azcopy/linux_amd64_10.8.0/azcopy"` | no |
| <a name="input_batch_account_name"></a> [batch\_account\_name](#input\_batch\_account\_name) | Name of the existing Batch account | `string` | `"seqeracomputebatch"` | no |
| <a name="input_batch_pool_name"></a> [batch\_pool\_name](#input\_batch\_pool\_name) | Name of the Batch pool to be created | `string` | `"seqerapool"` | no |
| <a name="input_identity_ids"></a> [identity\_ids](#input\_identity\_ids) | List of user assigned identity IDs to add to the Batch pool. If empty, no managed identities will be assigned | `list(string)` | `[]` | no |
| <a name="input_max_pool_size"></a> [max\_pool\_size](#input\_max\_pool\_size) | Maximum number of VMs in the pool | `number` | `8` | no |
| <a name="input_node_agent_sku_id"></a> [node\_agent\_sku\_id](#input\_node\_agent\_sku\_id) | SKU of the node agent. Must be compatible with the VM image | `string` | `"batch.node.ubuntu 20.04"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group | `string` | `"seqeracompute"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Optional ID of the subnet to connect the pool to | `string` | `null` | no |
| <a name="input_vm_image_offer"></a> [vm\_image\_offer](#input\_vm\_image\_offer) | Offer of the VM image | `string` | `"ubuntu-server-container"` | no |
| <a name="input_vm_image_publisher"></a> [vm\_image\_publisher](#input\_vm\_image\_publisher) | Publisher of the VM image | `string` | `"microsoft-azure-batch"` | no |
| <a name="input_vm_image_sku"></a> [vm\_image\_sku](#input\_vm\_image\_sku) | SKU of the VM image | `string` | `"20-04-lts"` | no |
| <a name="input_vm_image_version"></a> [vm\_image\_version](#input\_vm\_image\_version) | Version of the VM image | `string` | `"latest"` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Size of the VM to use in the Batch pool | `string` | `"Standard_E16d_v5"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_batch_pool_id"></a> [batch\_pool\_id](#output\_batch\_pool\_id) | The ID of the Azure Batch pool |
| <a name="output_batch_pool_name"></a> [batch\_pool\_name](#output\_batch\_pool\_name) | The name of the Azure Batch pool |
<!-- END_TF_DOCS -->