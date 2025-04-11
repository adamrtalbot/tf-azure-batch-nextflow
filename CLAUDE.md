# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains a Terraform module for creating Azure Batch pools optimized for running Nextflow workflows. It integrates with Seqera Platform using the official Seqera Terraform provider to provide a complete compute environment setup for bioinformatics and computational workflows.

## Architecture Overview

### Core Components

The module creates:
- **Azure Batch Pool**: Auto-scaling pool of Ubuntu VMs with Docker support
- **Seqera Integration**: Optional compute environment in Seqera Platform using native provider
- **Resource Management**: Smart VM sizing and task-per-node configuration

### Key Files Structure

```
main.tf           # Primary resource definitions and provider configuration
variables.tf      # Input variables with validation rules
outputs.tf        # Module outputs
README.md         # Comprehensive documentation with examples
*.tfvars          # Environment-specific variable files
```

### Auto-scaling Logic

The module implements sophisticated auto-scaling in `main.tf:125-143`:
- Initial deployment: `min_pool_size` nodes
- Scale up: Based on pending tasks count
- Scale down: 50% reduction when idle
- Evaluation interval: 5 minutes
- VM slots calculated from VM size (e.g., Standard_D4_v3 → 4 slots)

## Provider Information

### Hybrid Provider Approach

This module uses a hybrid approach combining two providers:
- **Seqera Provider** (`seqeralabs/seqera` v0.25.2): For compute environment management
- **REST API Provider** (`Mastercard/restapi`): For credential lookup by name

**Why Hybrid?**
- Seqera provider has better resource lifecycle management for compute environments
- REST API provider works reliably for credential name-based lookups
- Avoids provider bugs with credential data source

### Provider Responsibilities
- **Seqera Provider**: `seqera_compute_env` resource creation and management
- **REST API Provider**: Credential lookup by name via `/credentials` endpoint

## Development Workflow

### Essential Commands

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply configuration
terraform apply

# Destroy resources
terraform destroy

# Format code
terraform fmt

# Validate configuration
terraform validate
```

### Variable File Management

The module supports multiple `.tfvars` files for different environments:
- `terraform.tfvars` - Default configuration
- `alt.tfvars` - Alternative configuration
- `azure-showcase.tfvars` - Demo/showcase configuration
- `lonza-pool.tfvars` - Client-specific configuration

Use with: `terraform apply -var-file="alt.tfvars"`

### Testing Changes

1. Use `terraform plan -var-file="your.tfvars"` to preview changes
2. Test with minimal configurations first
3. Validate VM size compatibility with node agent SKU
4. Ensure managed identity exists before referencing

## Key Configuration Patterns

### VM Size and Slots Calculation

The module automatically extracts CPU count from VM size using regex in `main.tf:47`:
```hcl
slots = can(regex("[A-Za-z]+[Ss]?(\\d+)", var.vm_size)) ? tonumber(regex("[A-Za-z]+[Ss]?(\\d+)", var.vm_size)[0]) : 1
```

### Container Registry Authentication

Three authentication methods supported in `variables.tf:136-145`:
1. Username + Password
2. Managed Identity ID
3. Pool's managed identity (use_managed_identity = true)

### Seqera Platform Integration

When `create_seqera_compute_env = true`:
- Uses official Seqera Terraform provider
- Requires API endpoint and access token
- Fetches credentials by name via REST API (workaround for provider bug)
- Creates compute environment with proper resource management
- Supports heredoc syntax for multi-line scripts

### Manual Pool Mode Configuration

The compute environment is configured for manual Azure Batch pool mode:
- `head_pool` points to the Terraform-created batch pool
- `forge` block is required but configured with disabled settings:
  - `vm_count = 0` (no additional VMs created)
  - `auto_scale = false` (no auto-scaling by Seqera)
  - `dispose_on_deletion = true` (cleanup enabled)
- Compatible with Entra ID (Azure AD) authentication

## Critical Validation Rules

### VM Image SKU Format
- Must not contain periods (e.g., "2204" not "22.04")
- Validated in `variables.tf:43-46`

### Seqera Work Directory
- Must start with "az://" for Azure Blob Storage
- Validated in `variables.tf:196-199`

### Container Registry Uniqueness
- Each registry server must be unique
- Validated in `variables.tf:147-151`

## Troubleshooting Common Issues

### Provider Authentication
- **Azure**: Ensure Azure CLI is authenticated: `az login`
- **Azure Service Principals**: Set ARM_* environment variables
- **Seqera**: Set SEQERA_API_TOKEN environment variable or use provider configuration

### Managed Identity Issues
- Verify managed identity exists in specified resource group
- Check identity has necessary permissions for container registries

### Seqera Integration Failures
- **Entra Credentials with Forge**: "Entra credentials are not compatible with Azure Batch Forge compute environments" means forge mode should be disabled for manual pools
- Validate API token format and permissions for both providers
- Ensure workspace ID is correct
- Check credentials **name** exists in target workspace (REST API uses name-based lookup)
- Verify both provider versions are compatible
- REST API provider handles credential lookup, Seqera provider handles compute environment

### Auto-scaling Not Working
- Review evaluation interval (5 minutes default)
- Check pending tasks are being reported correctly
- Verify min/max pool size constraints

## Security Considerations

- Seqera access tokens are marked sensitive and managed by provider
- Container registry passwords are handled securely
- Managed identities preferred over service principals
- Network isolation supported via subnet configuration
- Official Seqera provider ensures proper API authentication