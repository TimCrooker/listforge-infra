variable "name" {
  description = "Service name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "image" {
  description = "Docker image URI"
  type        = string
}

variable "port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "CPU allocation (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Memory allocation (512, 1024, 2048, 3072, 4096, 6144, 8192, 10240, 12288)"
  type        = string
  default     = "512"

  validation {
    condition     = contains(["512", "1024", "2048", "3072", "4096", "6144", "8192", "10240", "12288"], var.memory)
    error_message = "Memory must be one of: 512, 1024, 2048, 3072, 4096, 6144, 8192, 10240, 12288."
  }
}

variable "environment_variables" {
  description = "Environment variables for the service"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets from AWS Secrets Manager (map of name to ARN)"
  type        = map(string)
  default     = {}
}

variable "vpc_connector_arn" {
  description = "VPC Connector ARN for private networking"
  type        = string
  default     = null
}

variable "domain" {
  description = "Custom domain for the service"
  type        = string
  default     = null
}

variable "zone_id" {
  description = "Route 53 zone ID for custom domain"
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "auto_deployments_enabled" {
  description = "Enable auto deployments from ECR"
  type        = bool
  default     = true
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for storage access (if null, no S3 policy is created)"
  type        = string
  default     = null
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1

  validation {
    condition     = var.min_size >= 1 && var.min_size <= 25
    error_message = "Minimum size must be between 1 and 25."
  }
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 3

  validation {
    condition     = var.max_size >= 1 && var.max_size <= 25
    error_message = "Maximum size must be between 1 and 25."
  }
}
