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
min_pool_size = 1
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
managed_identity_name           = "managed-identity-name"
managed_identity_resource_group = "managed-identity-resource-group"
```

If you want to add the compute pool to Seqera Platform, you can set the following variables:

```terraform
create_seqera_compute_env = true
seqera_api_endpoint       = "https://cloud.your-seqera.io/api"
seqera_access_token       = "eyJYOURACCESSTOKENHERE="
seqera_workspace_id       = "1234567890"
seqera_work_dir           = "az://azure-blob-container-name"
seqera_credentials_name   = "azure-creds"
seqera_pre_run_script     = <<-EOT
#!/bin/bash
echo 'Hello, world!'
EOT
seqera_post_run_script    = <<-EOT
#!/bin/bash
echo 'Goodbye, world!'
EOT
seqera_nextflow_config      = <<-EOT
process.queue = "auto"
process.machineType = "Standard_D*d_v5,Standard_E*d_v5"
azure.batch.pools.auto.autoScale = true
azure.batch.pools.auto.vmCount = 0
azure.batch.pools.auto.maxVmCount = 12
azure.batch.pools.auto.lowPriority = true
EOT
```

Run `terraform init` and `terraform apply` to create the Batch pool. You should see the pool created in the Azure portal.

> [!NOTE]
> For multi-line strings like `seqera_pre_run_script`, `seqera_post_run_script`, and `seqera_nextflow_config`, you must use heredoc syntax (`<<-EOT` and `EOT`) as shown in the example above. See Terraform documentation [here](https://developer.hashicorp.com/terraform/language/expressions/strings#heredoc-strings) for more information.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | ~> 1.18 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.117.0 |
| <a name="provider_restapi"></a> [restapi](#provider\_restapi) | 1.20.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_batch_pool.pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/batch_pool) | resource |
| [restapi_object.seqera_compute_env](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [terraform_data.compute_env_name](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.credentials_id](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.managed_identity_id](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.nextflow_config](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.post_run_script](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.pre_run_script](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azcopy_url"></a> [azcopy\_url](#input\_azcopy\_url) | URL to download azcopy binary | `string` | `"https://nf-xpack.seqera.io/azcopy/linux_amd64_10.8.0/azcopy"` | no |
| <a name="input_batch_account_name"></a> [batch\_account\_name](#input\_batch\_account\_name) | Name of the existing Batch account | `string` | `"seqeracomputebatch"` | no |
| <a name="input_batch_pool_name"></a> [batch\_pool\_name](#input\_batch\_pool\_name) | Name of the Batch pool to be created | `string` | `"seqerapool"` | no |
| <a name="input_create_seqera_compute_env"></a> [create\_seqera\_compute\_env](#input\_create\_seqera\_compute\_env) | Whether to create a seqera compute environment | `bool` | `false` | no |
| <a name="input_managed_identity_name"></a> [managed\_identity\_name](#input\_managed\_identity\_name) | Name of the managed identity to use with Azure Batch | `string` | `"nextflow-id"` | no |
| <a name="input_managed_identity_resource_group"></a> [managed\_identity\_resource\_group](#input\_managed\_identity\_resource\_group) | Resource group containing the managed identity | `string` | `null` | no |
| <a name="input_max_pool_size"></a> [max\_pool\_size](#input\_max\_pool\_size) | Maximum number of VMs in the pool | `number` | `8` | no |
| <a name="input_min_pool_size"></a> [min\_pool\_size](#input\_min\_pool\_size) | Minimum number of VMs in the pool | `number` | `0` | no |
| <a name="input_node_agent_sku_id"></a> [node\_agent\_sku\_id](#input\_node\_agent\_sku\_id) | SKU of the node agent. Must be compatible with the VM image | `string` | `"batch.node.ubuntu 20.04"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group of the Azure Batch account | `string` | `"seqeracompute"` | no |
| <a name="input_seqera_access_token"></a> [seqera\_access\_token](#input\_seqera\_access\_token) | Seqera API access token which must be generated from the Seqera Platform UI. | `string` | `null` | no |
| <a name="input_seqera_api_endpoint"></a> [seqera\_api\_endpoint](#input\_seqera\_api\_endpoint) | Seqera API endpoint URL. | `string` | `"https://api.cloud.seqera.io"` | no |
| <a name="input_seqera_compute_env_name"></a> [seqera\_compute\_env\_name](#input\_seqera\_compute\_env\_name) | Name of the Seqera compute environment. Defaults to batch\_pool\_name if not specified | `string` | `null` | no |
| <a name="input_seqera_credentials_name"></a> [seqera\_credentials\_name](#input\_seqera\_credentials\_name) | Name of the credentials in the workspace | `string` | `null` | no |
| <a name="input_seqera_nextflow_config"></a> [seqera\_nextflow\_config](#input\_seqera\_nextflow\_config) | Optional Nextflow config content to be used in the compute environment. Can be a multi-line string using heredoc syntax. | `string` | `null` | no |
| <a name="input_seqera_post_run_script"></a> [seqera\_post\_run\_script](#input\_seqera\_post\_run\_script) | Optional script to run after each task execution. Can be a multi-line string using heredoc syntax. | `string` | `null` | no |
| <a name="input_seqera_pre_run_script"></a> [seqera\_pre\_run\_script](#input\_seqera\_pre\_run\_script) | Optional script to run before each task execution. Can be a multi-line string using heredoc syntax. | `string` | `null` | no |
| <a name="input_seqera_work_dir"></a> [seqera\_work\_dir](#input\_seqera\_work\_dir) | Work directory for the Seqera compute environment which is typically an Azure Blob Storage container. Must start with 'az://' | `string` | `null` | no |
| <a name="input_seqera_workspace_id"></a> [seqera\_workspace\_id](#input\_seqera\_workspace\_id) | Seqera workspace ID where the compute environment will be created. Can by looking at the list of workspaces within an organization on the Seqera Platform. | `number` | `null` | no |
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
| <a name="output_credentials_id"></a> [credentials\_id](#output\_credentials\_id) | The ID of the credentials |
| <a name="output_managed_identity_client_id"></a> [managed\_identity\_client\_id](#output\_managed\_identity\_client\_id) | The client ID of the managed identity |
| <a name="output_seqera_compute_env_id"></a> [seqera\_compute\_env\_id](#output\_seqera\_compute\_env\_id) | The ID of the Tower compute environment |
<!-- END_TF_DOCS -->