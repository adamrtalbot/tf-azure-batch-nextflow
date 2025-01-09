variable "resource_group_name" {
  description = "Name of the resource group"
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

variable "identity_ids" {
  description = "List of user assigned identity IDs to add to the Batch pool. If empty, no managed identities will be assigned"
  type        = list(string)
  default     = []
}
