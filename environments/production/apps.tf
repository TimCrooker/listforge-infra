# Production Apps - Define all App Runner services here
# Add new apps by copying a module block and changing the values

locals {
  # Common environment variables for all apps
  common_env = {
    NODE_ENV         = "production"
    STORAGE_PROVIDER = "s3"
    S3_BUCKET        = module.storage.bucket_name
    S3_REGION        = local.region
  }

  # API-specific environment
  api_env = merge(local.common_env, {
    PORT         = "3001"
    DATABASE_URL = module.database.connection_url
    REDIS_URL    = module.cache.connection_url
    JWT_SECRET   = var.jwt_secret
    FRONTEND_URL = "https://${var.domain}"
  })

  # Web-specific environment (mostly static, API URL baked in at build time)
  web_env = merge(local.common_env, {
    PORT = "80"
  })
}

# ECR Repositories
module "ecr" {
  source = "../../shared"

  app_names = ["listforge-api", "listforge-web"]
}

# API Service
module "api" {
  source = "../../modules/app-service"

  name        = "listforge-api"
  project     = var.project
  environment = var.environment

  image = "${local.ecr_registry}/listforge-api:latest"
  port  = 3001
  cpu   = "256"
  memory = "512"

  environment_variables = local.api_env
  vpc_connector_arn     = module.networking.vpc_connector_arn

  domain  = "api.${var.domain}"
  zone_id = module.dns.zone_id

  health_check_path = "/api/health"
  min_size          = 1
  max_size          = 3
}

# Web Service
module "web" {
  source = "../../modules/app-service"

  name        = "listforge-web"
  project     = var.project
  environment = var.environment

  image = "${local.ecr_registry}/listforge-web:latest"
  port  = 80
  cpu   = "256"
  memory = "512"

  environment_variables = local.web_env

  domain  = var.domain
  zone_id = module.dns.zone_id

  health_check_path = "/"
  min_size          = 1
  max_size          = 3
}

# =============================================================================
# ADD NEW APPS HERE
# =============================================================================
# Example: Admin Dashboard
# module "admin" {
#   source = "../../modules/app-service"
#
#   name        = "listforge-admin"
#   project     = var.project
#   environment = var.environment
#
#   image = "${local.ecr_registry}/listforge-admin:latest"
#   port  = 3000
#
#   environment_variables = local.common_env
#   vpc_connector_arn     = module.networking.vpc_connector_arn
#
#   domain  = "admin.${var.domain}"
#   zone_id = module.dns.zone_id
# }
# =============================================================================

