# Production Outputs

# DNS
output "name_servers" {
  description = "Route 53 name servers - update your domain registrar with these"
  value       = module.dns.zone_name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.dns.certificate_arn
}

# Database
output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.endpoint
}

output "database_connection_url" {
  description = "Database connection URL"
  value       = module.database.connection_url
  sensitive   = true
}

# Cache
output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.cache.endpoint
}

output "redis_connection_url" {
  description = "Redis connection URL"
  value       = module.cache.connection_url
}

# Storage
output "s3_bucket" {
  description = "S3 bucket name"
  value       = module.storage.bucket_name
}

# ECR
output "ecr_registry" {
  description = "ECR registry URL"
  value       = local.ecr_registry
}

output "ecr_repositories" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

# App Services
output "api_url" {
  description = "API service URL"
  value       = module.api.service_url
}

output "api_custom_domain" {
  description = "API custom domain"
  value       = module.api.custom_domain
}

output "api_service_arn" {
  description = "API service ARN"
  value       = module.api.service_arn
}

output "web_url" {
  description = "Web service URL"
  value       = module.web.service_url
}

output "web_custom_domain" {
  description = "Web custom domain"
  value       = module.web.custom_domain
}

output "web_service_arn" {
  description = "Web service ARN"
  value       = module.web.service_arn
}

output "landing_url" {
  description = "Landing service URL"
  value       = module.landing.service_url
}

output "landing_custom_domain" {
  description = "Landing custom domain"
  value       = module.landing.custom_domain
}

output "landing_service_arn" {
  description = "Landing service ARN"
  value       = module.landing.service_arn
}

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "vpc_connector_arn" {
  description = "VPC Connector ARN"
  value       = module.networking.vpc_connector_arn
}

