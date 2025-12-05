# ListForge Infrastructure

Terraform infrastructure for ListForge - a scalable, multi-app AWS deployment.

## Architecture

```
Route 53: list-forge.ai
├── list-forge.ai        → listforge-web (App Runner)
├── api.list-forge.ai    → listforge-api (App Runner)
└── *.list-forge.ai      → Wildcard SSL (ACM)
```

## Resources

- **Compute**: AWS App Runner (auto-scaling containers)
- **Database**: RDS PostgreSQL
- **Cache**: ElastiCache Redis
- **Storage**: S3
- **DNS**: Route 53
- **SSL**: ACM Certificates
- **Container Registry**: ECR

## Usage

### Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured
- GitHub CLI (for CI/CD setup)

### Deploy

```bash
cd environments/production
terraform init
terraform plan
terraform apply
```

### Add a New App

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

- **PR**: `terraform plan` runs automatically
- **Merge to main**: `terraform apply` runs automatically

## State

State is stored in S3 with DynamoDB locking:
- Bucket: `listforge-terraform-state`
- Lock Table: `terraform-locks`

