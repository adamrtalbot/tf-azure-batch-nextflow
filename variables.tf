variable "resource_group_name" {
  description = "Name of the resource group of the Azure Batch account"
  type        = string
  default     = "seqeracompute"
}
variable "batch_account_name" {
  description = "Name of the existing Batch account"
  type        = string
  default     = "seqeracomputebatch"
}

variable "batch_pool_name" {
  description = "Name of the Batch pool to be created"
  type        = string
  default     = "seqerapool"
}

variable "vm_size" {
  description = "Size of the VM to use in the Batch pool"
  type        = string
  default     = "Standard_E16d_v5"
}

variable "max_pool_size" {
  description = "Maximum number of VMs in the pool"
  type        = number
  default     = 8
}

variable "vm_image_publisher" {
  description = "Publisher of the VM image"
  type        = string
  default     = "microsoft-azure-batch"
}

variable "vm_image_offer" {
  description = "Offer of the VM image"
  type        = string
  default     = "ubuntu-server-container"
}

variable "vm_image_sku" {
  description = "SKU of the VM image"
  type        = string
  default     = "20-04-lts"
}

variable "vm_image_version" {
  description = "Version of the VM image"
  type        = string
  default     = "latest"
}

variable "node_agent_sku_id" {
  description = "SKU of the node agent. Must be compatible with the VM image"
  type        = string
  default     = "batch.node.ubuntu 20.04"
}

variable "azcopy_url" {
  description = "URL to download azcopy binary"
  type        = string
  default     = "https://nf-xpack.seqera.io/azcopy/linux_amd64_10.8.0/azcopy"
}

variable "subnet_id" {
  description = "Optional ID of the subnet to connect the pool to"
  type        = string
  default     = null
}

variable "managed_identity_name" {
  description = "Name of the managed identity to use with Azure Batch"
  type        = string
  default     = "nextflow-id"
}

variable "managed_identity_resource_group" {
  description = "Resource group containing the managed identity"
  type        = string
  default     = null
}

variable "min_pool_size" {
  description = "Minimum number of VMs in the pool"
  type        = number
  default     = 0
}

variable "create_seqera_compute_env" {
  description = "Whether to create a seqera compute environment"
  type        = bool
  default     = false
}

variable "seqera_api_endpoint" {
  description = "Seqera API endpoint URL."
  type        = string
  default     = "https://api.cloud.seqera.io"
}

variable "seqera_access_token" {
  description = "Seqera API access token which must be generated from the Seqera Platform UI."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = var.seqera_access_token == null || can(regex("^[A-Za-z0-9_=-]{10,}$", var.seqera_access_token))
    error_message = "The seqera_access_token must be null or a valid token format starting with 'eyJ' and containing a period."
  }
}

variable "seqera_workspace_id" {
  description = "Seqera workspace ID where the compute environment will be created. Can by looking at the list of workspaces within an organization on the Seqera Platform."
  type        = number
  default     = null
}

variable "seqera_compute_env_name" {
  description = "Name of the Seqera compute environment. Defaults to batch_pool_name if not specified"
  type        = string
  default     = null
}

variable "seqera_work_dir" {
  description = "Work directory for the Seqera compute environment which is typically an Azure Blob Storage container. Must start with 'az://'"
  type        = string
  default     = null

  validation {
    condition     = var.seqera_work_dir == null || can(regex("^az://", var.seqera_work_dir))
    error_message = "The seqera_work_dir must start with 'az://'."
  }
}

variable "seqera_credentials_name" {
  description = "Name of the credentials in the workspace"
  type        = string
  default     = null
}

variable "seqera_pre_run_script" {
  description = "Optional script to run before each task execution. Can be a multi-line string using heredoc syntax."
  type        = string
  default     = null
  nullable    = true
}

variable "seqera_post_run_script" {
  description = "Optional script to run after each task execution. Can be a multi-line string using heredoc syntax."
  type        = string
  default     = null
  nullable    = true
}

variable "seqera_nextflow_config" {
  description = "Optional Nextflow config content to be used in the compute environment. Can be a multi-line string using heredoc syntax."
  type        = string
  default     = null
  nullable    = true
}
