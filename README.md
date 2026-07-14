# Azure Batch Pool for Nextflow

This Terraform configuration creates an Azure Batch pool optimized for running Nextflow workflows. The pool is configured with Ubuntu containers and includes the necessary tools for Nextflow execution.

## Description

This module creates an Azure Batch pool with:

- Docker-compatible nodes (Microsoft DSVM Ubuntu 22.04 LTS by default)
- Automatic scaling based on pending tasks with a 5-minute evaluation interval
- Maximum tasks per node set to match the VM's CPU core count
- Pre-installed azcopy for efficient data transfer using the startTask
- Auto-scaling formula that:
  - Deploys 1 node initially
  - Scales based on pending tasks
  - Scales down to 50% when idle
  - Respects maximum pool size limit

## Usage

Create a `terraform.tfvars` file with your variables:

### Minimal example

Here is a minimal example of the `terraform.tfvars` file:

```terraform
# Minimal example
resource_group_name = "my_batch_account_resource_group"
batch_account_name = "mybatchaccount"
batch_pool_name = "mypool"
```

If you want to add the compute pool to Seqera Platform, you can set the following variables:

```terraform
create_seqera_compute_env = true
seqera_api_endpoint       = "https://cloud.your-seqera.io/api"
seqera_access_token       = "eyJYOURACCESSTOKENHERE="
seqera_workspace_id       = "1234567890"
seqera_work_dir           = "az://azure-blob-container-name"
seqera_credentials_name   = "azure-creds"
```

### Full example

Here is a more complete example of the `terraform.tfvars` file, which also:

 - Uses a smaller VM size
 - Adds a managed identity to the pool for Entra authentication
 - Allows the pool to access a private container registry
 - Attaches the compute pool to a specific subnet
 - Installs a more recent version of azcopy from microsoft
 - Adds the compute pool to Seqera Platform
 - Uses the autopool feature to allow Nextflow to create pools dynamically
 - Adds a pre and post run script to the compute pool

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
vm_image_publisher = "microsoft-dsvm"
vm_image_offer = "ubuntu-hpc"
vm_image_sku = "2404"
vm_image_version = "latest"
node_agent_sku_id = "batch.node.ubuntu 24.04"

# Start task configuration, use to install the most recent version of azcopy
start_task_command_line = "bash -c \"tar -xzvf azcopy.tar.gz && chmod +x azcopy*/azcopy && mkdir -p $AZ_BATCH_NODE_SHARED_DIR/bin/ && cp azcopy*/azcopy $AZ_BATCH_NODE_SHARED_DIR/bin/\""
start_task_resource_files = [
  {
    url = "https://github.com/Azure/azure-storage-azcopy/releases/download/v10.28.1/azcopy_linux_amd64_10.28.1.tar.gz"
    file_path = "azcopy.tar.gz"
  }
]
start_task_elevation_level = "NonAdmin"
start_task_scope = "Pool"

# Optional networking configuration
subnet_id = "/subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.Network/virtualNetworks/<vnet_name>/subnets/<subnet_name>"

# Optional managed identity configuration
managed_identity_name           = "managed-identity-name"
managed_identity_resource_group = "managed-identity-resource-group"

# Optional container registries configuration
# Can use:
# 1) username AND password
# 2) identity_id
# 3) use_managed_identity = true (pool's managed identity will be used)
container_registries = [
  {
    registry_server = "my-registry-server-1.azurecr.io"
    user_name       = "my-username"
    password        = "my-password"
  },
  {
    registry_server     = "my-registry-server-2.azurecr.io"
    use_managed_identity = true
  }
]
```

You can configure additional compute environment settings to Seqera Platform via these variables:

```terraform
create_seqera_compute_env = true
seqera_api_endpoint       = "https://cloud.your-seqera.io/api"
seqera_access_token       = "eyJYOURACCESSTOKENHERE="
seqera_workspace_id       = "1234567890"
seqera_work_dir           = "az://azure-blob-container-name"
seqera_credentials_name   = "azure-creds"
seqera_pre_run_script     = <<-EOT
echo 'Hello, world!'
EOT
seqera_post_run_script    = <<-EOT
echo 'Goodbye, world!'
EOT
seqera_nextflow_config      = <<-EOT
process.queue = "auto"
process.machineType = "Standard_D*d_v5,Standard_E*d_v5"
azure.batch.allowPoolCreation = true
azure.batch.autoPoolMode = true
azure.batch.pools.auto.autoScale = true
azure.batch.pools.auto.vmCount = 0
azure.batch.pools.auto.maxVmCount = 12
azure.batch.pools.auto.lowPriority = true
azure.batch.pools.auto.virtualNetwork = "/subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.Network/virtualNetworks/<vnet_name>/subnets/<subnet_name>"
EOT
```

Run `terraform init` and `terraform apply` to create the Batch pool. You should see the pool created in the Azure portal.

> [!NOTE]
> For multi-line strings like `seqera_pre_run_script`, `seqera_post_run_script`, and `seqera_nextflow_config`, you must use heredoc syntax (`<<-EOT` and `EOT`) as shown in the example above. See Terraform documentation [here](https://developer.hashicorp.com/terraform/language/expressions/strings#heredoc-strings) for more information.

### Enabling Fusion v2

Set `enable_fusion = true` to run pipelines with the [Fusion v2](https://docs.seqera.io/fusion) file system. When enabled, the module:

- Installs and loads the `seqera-fusionfs-container` AppArmor profile on each pool node via the start task. AppArmor enforcement on Ubuntu 24.04+ nodes requires this profile so Fusion can mount its FUSE filesystem.
- Forces the start task to run with `Admin` elevation (writing to `/etc/apparmor.d` and running `apparmor_parser` require root).
- Enables Wave and Fusion on the Seqera compute environment (Fusion requires Wave).

Seqera Platform automatically passes `--security-opt apparmor=seqera-fusionfs-container` to task containers, so no additional `containerOptions` configuration is needed.

```terraform
create_seqera_compute_env = true
enable_fusion             = true
# Fusion's AppArmor profile targets the AppArmor 4.0 ABI, so use Ubuntu 24.04 nodes:
vm_image_sku      = "2404"
node_agent_sku_id = "batch.node.ubuntu 24.04"
```

### Dual pool mode

Set `enable_dual_pool = true` to create a separate worker pool alongside the existing pool. The existing pool becomes the **head pool**, which runs the Nextflow driver job. Tasks are routed to the **worker pool**. This lets the head node and workers use different VM sizes and different managed identities, which improves both efficiency (a small head node, cheap auto-scaling workers) and security posture (the head identity and worker identity can be scoped separately).

Enabling dual pool mode does not change the existing pool's Terraform state: the head pool keeps the `azurerm_batch_pool.pool` address and the worker pool is added as `azurerm_batch_pool.worker[0]`. With `enable_dual_pool = false` (the default) the module behaves exactly as before.

```terraform
create_seqera_compute_env = true

# Head pool (existing variables)
batch_pool_name       = "mypool"
vm_size               = "Standard_E8d_v5"
min_pool_size         = 0
max_pool_size         = 1
managed_identity_name = "nextflow-head-id"

# Worker pool
enable_dual_pool             = true
worker_vm_size               = "Standard_E16d_v5"
worker_min_pool_size         = 0
worker_max_pool_size         = 8
worker_managed_identity_name = "nextflow-worker-id" # recommended: a distinct identity
```

Both managed identities must already exist and be resolvable via the `azurerm_user_assigned_identity` data source (name plus resource group). This module references the identities; it does not create them or assign their roles. If `worker_managed_identity_name` is omitted, the worker pool reuses the head identity, which removes the security benefit.

#### Required role assignments

The security benefit of dual pool mode comes entirely from scoping the two identities differently. Assign these roles (outside this module) before running a pipeline:

| Identity | Role | Scope | Why |
|----------|------|-------|-----|
| Head (`managed_identity_name`) | Storage Blob Data Contributor | Work-directory storage account | Head node reads/writes the work directory |
| Head (`managed_identity_name`) | Azure Batch Data Contributor | Batch account | Head node (Nextflow driver) submits tasks to the worker pool |
| Worker (`worker_managed_identity_name`) | Storage Blob Data Contributor | Work-directory storage account | Workers read/write the work directory |

The worker identity deliberately gets **no Batch role** — workers only move data, they never talk to the Batch API. That least-privilege split is the point of using a separate worker identity; reusing the head identity for both pools gives every task node full Batch data-plane access.

#### Provider field mapping

The head/worker pool names and the per-pool managed-identity fields are set on the `seqera_compute_env` resource using the `seqeralabs/seqera` provider's manual (named-pool) config. `head_pool`, `worker_pool`, `managed_identity_client_id`, `managed_identity_head_resource_id`, `managed_identity_pool_client_id`, and `managed_identity_pool_resource_id` are all sibling `config.azure_batch` attributes at v0.41.x, so manual named pools and per-pool identities compose. `managed_identity_client_id` + `managed_identity_head_resource_id` identify the head (driver) identity; `managed_identity_pool_client_id` + `managed_identity_pool_resource_id` identify the worker-pool identity.

> **Verify runtime behaviour before production use.** This four-field identity mapping matches a working Batch Forge dual-pool deployment, but Forge auto-creates its pools whereas this module wires the identities to manually created named pools. Run `terraform plan` and a test pipeline against a real workspace to confirm before relying on this in production.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.0 |
| <a name="requirement_seqera"></a> [seqera](#requirement\_seqera) | ~> 0.41.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.117.1 |
| <a name="provider_seqera"></a> [seqera](#provider\_seqera) | 0.41.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_batch_pool.pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/batch_pool) | resource |
| [azurerm_batch_pool.worker](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/batch_pool) | resource |
| [seqera_compute_env.azure_batch](https://registry.terraform.io/providers/seqeralabs/seqera/latest/docs/resources/compute_env) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_batch_account_name"></a> [batch\_account\_name](#input\_batch\_account\_name) | Name of the existing Batch account | `string` | n/a | yes |
| <a name="input_batch_pool_name"></a> [batch\_pool\_name](#input\_batch\_pool\_name) | Name of the Batch pool to be created | `string` | n/a | yes |
| <a name="input_container_registries"></a> [container\_registries](#input\_container\_registries) | List of container registries to be used in the Batch pool's container configuration. For each registry, provide either username+password OR set use\_managed\_identity to true. When use\_managed\_identity is true, the pool's managed identity will be used. | <pre>list(object({<br>    registry_server      = string<br>    user_name            = optional(string)<br>    password             = optional(string)<br>    identity_id          = optional(string)<br>    use_managed_identity = optional(bool, false)<br>  }))</pre> | `[]` | no |
| <a name="input_create_seqera_compute_env"></a> [create\_seqera\_compute\_env](#input\_create\_seqera\_compute\_env) | Whether to create a seqera compute environment | `bool` | `false` | no |
| <a name="input_enable_dual_pool"></a> [enable\_dual\_pool](#input\_enable\_dual\_pool) | Enable dual pool mode: create a separate worker pool alongside the existing (head) pool. The head pool runs the Nextflow driver job and tasks are routed to the worker pool. Defaults to false, in which case the module behaves exactly as before (single pool). | `bool` | `false` | no |
| <a name="input_enable_fusion"></a> [enable\_fusion](#input\_enable\_fusion) | Enable Fusion v2 support in the compute environment. Implies enable\_wave (Fusion requires Wave). | `bool` | `false` | no |
| <a name="input_enable_wave"></a> [enable\_wave](#input\_enable\_wave) | Enable the Wave container service in the compute environment. Automatically enabled when enable\_fusion is true; set independently to use Wave without Fusion. | `bool` | `false` | no |
| <a name="input_managed_identity_name"></a> [managed\_identity\_name](#input\_managed\_identity\_name) | Name of the managed identity to use with Azure Batch | `string` | `"nextflow-id"` | no |
| <a name="input_managed_identity_resource_group"></a> [managed\_identity\_resource\_group](#input\_managed\_identity\_resource\_group) | Resource group containing the managed identity | `string` | `null` | no |
| <a name="input_max_pool_size"></a> [max\_pool\_size](#input\_max\_pool\_size) | Maximum number of VMs in the pool | `number` | `8` | no |
| <a name="input_min_pool_size"></a> [min\_pool\_size](#input\_min\_pool\_size) | Minimum number of VMs in the pool | `number` | `0` | no |
| <a name="input_node_agent_sku_id"></a> [node\_agent\_sku\_id](#input\_node\_agent\_sku\_id) | SKU of the node agent. Must be compatible with the VM image | `string` | `"batch.node.ubuntu 24.04"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group of the Azure Batch account | `string` | n/a | yes |
| <a name="input_seqera_access_token"></a> [seqera\_access\_token](#input\_seqera\_access\_token) | Seqera API access token which must be generated from the Seqera Platform UI. | `string` | `null` | no |
| <a name="input_seqera_api_endpoint"></a> [seqera\_api\_endpoint](#input\_seqera\_api\_endpoint) | Seqera API endpoint URL. | `string` | `"https://api.cloud.seqera.io"` | no |
| <a name="input_seqera_compute_env_name"></a> [seqera\_compute\_env\_name](#input\_seqera\_compute\_env\_name) | Name of the Seqera compute environment. Defaults to batch\_pool\_name if not specified | `string` | `null` | no |
| <a name="input_seqera_credentials_name"></a> [seqera\_credentials\_name](#input\_seqera\_credentials\_name) | Name of the credentials in the workspace | `string` | `null` | no |
| <a name="input_seqera_nextflow_config"></a> [seqera\_nextflow\_config](#input\_seqera\_nextflow\_config) | Optional Nextflow config content to be used in the compute environment. Can be a multi-line string using heredoc syntax. | `string` | `null` | no |
| <a name="input_seqera_post_run_script"></a> [seqera\_post\_run\_script](#input\_seqera\_post\_run\_script) | Optional script to run after each task execution. Can be a multi-line string using heredoc syntax. | `string` | `null` | no |
| <a name="input_seqera_pre_run_script"></a> [seqera\_pre\_run\_script](#input\_seqera\_pre\_run\_script) | Optional script to run before each task execution. Can be a multi-line string using heredoc syntax. | `string` | `null` | no |
| <a name="input_seqera_work_dir"></a> [seqera\_work\_dir](#input\_seqera\_work\_dir) | Work directory for the Seqera compute environment which is typically an Azure Blob Storage container. Must start with 'az://' | `string` | `null` | no |
| <a name="input_seqera_workspace_id"></a> [seqera\_workspace\_id](#input\_seqera\_workspace\_id) | Seqera workspace ID where the compute environment will be created. Can by looking at the list of workspaces within an organization on the Seqera Platform. | `number` | `null` | no |
| <a name="input_start_task_command_line"></a> [start\_task\_command\_line](#input\_start\_task\_command\_line) | Command line to run on the start task | `string` | `"bash -c \"tar -xzvf azcopy.tar.gz && chmod +x azcopy*/azcopy && mkdir -p $AZ_BATCH_NODE_SHARED_DIR/bin/ && cp azcopy*/azcopy $AZ_BATCH_NODE_SHARED_DIR/bin/\""` | no |
| <a name="input_start_task_elevation_level"></a> [start\_task\_elevation\_level](#input\_start\_task\_elevation\_level) | Elevation level for the start task | `string` | `"NonAdmin"` | no |
| <a name="input_start_task_resource_files"></a> [start\_task\_resource\_files](#input\_start\_task\_resource\_files) | URL to download azcopy binary | <pre>list(object({<br>    url       = string<br>    file_path = string<br>  }))</pre> | <pre>[<br>  {<br>    "file_path": "azcopy",<br>    "url": "https://nf-xpack.seqera.io/azcopy/linux_amd64_10.8.0/azcopy"<br>  }<br>]</pre> | no |
| <a name="input_start_task_scope"></a> [start\_task\_scope](#input\_start\_task\_scope) | Scope for the start task | `string` | `"Pool"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Optional ID of the subnet to connect the pool to | `string` | `null` | no |
| <a name="input_vm_image_offer"></a> [vm\_image\_offer](#input\_vm\_image\_offer) | Offer of the VM image | `string` | `"ubuntu-hpc"` | no |
| <a name="input_vm_image_publisher"></a> [vm\_image\_publisher](#input\_vm\_image\_publisher) | Publisher of the VM image | `string` | `"microsoft-dsvm"` | no |
| <a name="input_vm_image_sku"></a> [vm\_image\_sku](#input\_vm\_image\_sku) | SKU of the VM image | `string` | `"2404"` | no |
| <a name="input_vm_image_version"></a> [vm\_image\_version](#input\_vm\_image\_version) | Version of the VM image | `string` | `"latest"` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Size of the VM to use in the Batch pool | `string` | `"Standard_E16d_v5"` | no |
| <a name="input_worker_managed_identity_name"></a> [worker\_managed\_identity\_name](#input\_worker\_managed\_identity\_name) | Name of a separate managed identity for the worker pool (dual pool mode). Recommended for the security benefit of dual pool mode. If null, the worker pool reuses the head managed identity. | `string` | `null` | no |
| <a name="input_worker_managed_identity_resource_group"></a> [worker\_managed\_identity\_resource\_group](#input\_worker\_managed\_identity\_resource\_group) | Resource group containing the worker managed identity. Defaults to managed\_identity\_resource\_group if not set. | `string` | `null` | no |
| <a name="input_worker_max_pool_size"></a> [worker\_max\_pool\_size](#input\_worker\_max\_pool\_size) | Maximum number of VMs in the worker pool (dual pool mode). | `number` | `8` | no |
| <a name="input_worker_min_pool_size"></a> [worker\_min\_pool\_size](#input\_worker\_min\_pool\_size) | Minimum number of VMs in the worker pool (dual pool mode). | `number` | `0` | no |
| <a name="input_worker_pool_name"></a> [worker\_pool\_name](#input\_worker\_pool\_name) | Name of the worker Batch pool (dual pool mode). Defaults to '<batch\_pool\_name>-worker' if not set. | `string` | `null` | no |
| <a name="input_worker_vm_size"></a> [worker\_vm\_size](#input\_worker\_vm\_size) | VM size for the worker pool (dual pool mode). Defaults to Standard\_E16d\_v5 (the same default as the head vm\_size); set explicitly to give workers a different size than the head node. | `string` | `"Standard_E16d_v5"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_batch_pool_id"></a> [batch\_pool\_id](#output\_batch\_pool\_id) | The ID of the Azure Batch pool |
| <a name="output_batch_pool_name"></a> [batch\_pool\_name](#output\_batch\_pool\_name) | The name of the Azure Batch pool |
| <a name="output_credentials_id"></a> [credentials\_id](#output\_credentials\_id) | The ID of the credentials |
| <a name="output_managed_identity_client_id"></a> [managed\_identity\_client\_id](#output\_managed\_identity\_client\_id) | The client ID of the managed identity |
| <a name="output_seqera_compute_env_id"></a> [seqera\_compute\_env\_id](#output\_seqera\_compute\_env\_id) | The ID of the Seqera compute environment |
| <a name="output_worker_managed_identity_client_id"></a> [worker\_managed\_identity\_client\_id](#output\_worker\_managed\_identity\_client\_id) | The client ID of the managed identity used by the worker pool (null unless dual pool mode is enabled) |
| <a name="output_worker_pool_id"></a> [worker\_pool\_id](#output\_worker\_pool\_id) | The ID of the worker Azure Batch pool (null unless dual pool mode is enabled) |
| <a name="output_worker_pool_name"></a> [worker\_pool\_name](#output\_worker\_pool\_name) | The name of the worker Azure Batch pool (null unless dual pool mode is enabled) |
<!-- END_TF_DOCS -->
