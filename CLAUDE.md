# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Purpose

Terraform module that creates an auto-scaling Azure Batch pool (Ubuntu VMs with Docker) optimized for Nextflow workflows, with optional Seqera Platform integration via the official Seqera provider.

## Files

- `main.tf` — resources and provider configuration
- `variables.tf` — input variables and validation rules
- `outputs.tf` — module outputs
- `*.tfvars` — per-environment configs (apply with `-var-file="<file>.tfvars"`)

## Providers

- **Seqera** (`seqeralabs/seqera` ~> 0.41.0): looks up credentials by name (`seqera_credentials`) and manages compute environments (`seqera_compute_env`). Requires Terraform >= 1.11 (write-only credential arguments).
- **Azure**: authenticate via `az login` or `ARM_*` env vars. Set `SEQERA_API_TOKEN` for Seqera.

## Commands

```bash
terraform init
terraform plan -var-file="<file>.tfvars"
terraform apply -var-file="<file>.tfvars"
terraform fmt
terraform validate
```

## Validation rules (in variables.tf)

- VM image SKU must not contain periods (e.g. `2204`, not `22.04`).
- Seqera work directory must start with `az://`.
- Each container registry server must be unique.
- VM slots are derived from the VM size (e.g. `Standard_D4_v3` → 4 slots).
