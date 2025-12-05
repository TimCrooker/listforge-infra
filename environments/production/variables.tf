# Production Variables

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "listforge"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "domain" {
  description = "Root domain name"
  type        = string
  default     = "list-forge.ai"
}

# Database
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

# Cache
variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

# Storage
variable "storage_bucket_suffix" {
  description = "Suffix for S3 bucket name"
  type        = string
  default     = ""
}

# Secrets (should be passed via environment or tfvars)
variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
}

