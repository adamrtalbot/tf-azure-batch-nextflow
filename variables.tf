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
  default     = "rg-joint-jackass"
}

variable "min_pool_size" {
  description = "Minimum number of VMs in the pool"
  type        = number
  default     = 0
}

variable "create_tower_compute_env" {
  description = "Whether to create a Tower compute environment"
  type        = bool
  default     = false
}

variable "tower_api_endpoint" {
  description = "Tower API endpoint URL"
  type        = string
  default     = "https://api.cloud.seqera.io"
}

variable "tower_access_token" {
  description = "Tower API access token"
  type        = string
  default     = null
  sensitive   = true
}

variable "tower_workspace_id" {
  description = "Tower workspace ID where the compute environment will be created"
  type        = number
  default     = null
}

variable "tower_compute_env_name" {
  description = "Name of the Tower compute environment. Defaults to batch_pool_name if not specified"
  type        = string
  default     = null
}

variable "tower_work_dir" {
  description = "Work directory for the Tower compute environment. Must start with 'az://'"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^az://", var.tower_work_dir))
    error_message = "The tower_work_dir must start with 'az://'."
  }
}

variable "tower_credentials_id" {
  description = "Tower Azure credentials ID"
  type        = string
  default     = null
}
