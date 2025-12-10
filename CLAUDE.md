# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform infrastructure-as-code project for ListForge, managing AWS cloud infrastructure. The project deploys a multi-app architecture using AWS App Runner for containerized services, with RDS PostgreSQL for database, ElastiCache Redis for caching, and S3 for storage.

## Common Commands

All Terraform commands should be run from the environment directory:

```bash
cd environments/production

# Initialize Terraform (required before first use or after adding modules)
terraform init

# Format check (enforced in CI)
terraform fmt -check -recursive ../..

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply
```

## Architecture

```
Route 53: list-forge.ai
├── list-forge.ai        → listforge-web (App Runner)
├── api.list-forge.ai    → listforge-api (App Runner)
└── *.list-forge.ai      → Wildcard SSL (ACM)
```

**Key architectural decisions:**

- AWS App Runner provides serverless container hosting with auto-scaling (1-3 instances per service)
- VPC Connector enables App Runner to reach private resources (RDS, ElastiCache)
- Database has public accessibility enabled for App Runner connectivity (architecture constraint)
- Secrets stored in AWS Secrets Manager, not in Terraform state
- S3 bucket configured for public read access (for uploaded files)

## Project Structure

- `environments/production/` - Production environment configuration
  - `main.tf` - Provider setup, backend config, module orchestration
  - `apps.tf` - Application service definitions with shared environment variables
  - `variables.tf` - Input variables
  - `outputs.tf` - Output values
- `modules/` - Reusable infrastructure modules (app-service, database, cache, networking, dns, storage)
- `shared/ecr.tf` - ECR repositories for container images

## Adding a New Application

Edit `environments/production/apps.tf`:

```hcl
module "my_new_app" {
  source            = "../../modules/app-service"
  name              = "listforge-newapp"
  domain            = "newapp.list-forge.ai"
  image             = "${local.ecr_registry}/listforge-newapp:latest"
  port              = 3000
  environment       = local.common_env_vars
  vpc_connector_arn = module.networking.vpc_connector_arn
  zone_id           = module.dns.zone_id
  certificate_arn   = module.dns.certificate_arn
}
```

## CI/CD

GitHub Actions workflows handle deployment:

- **PRs to main**: `terraform plan` runs and comments on the PR
- **Push to main**: `terraform apply -auto-approve` runs automatically

## State Management

Terraform state is stored in S3 with DynamoDB locking:

- Bucket: `listforge-terraform-state`
- Lock Table: `terraform-locks`
- Region: `us-east-1`

## Key Configuration Defaults

- AWS Region: `us-east-1`
- Domain: `list-forge.ai`
- Database: `db.t3.micro` PostgreSQL 15
- Cache: `cache.t3.micro` Redis 7.0
- App Runner: 256 CPU / 512 MB memory per instance
