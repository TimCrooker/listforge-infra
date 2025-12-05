# App Service Module - Reusable App Runner Service

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

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
}

variable "memory" {
  description = "Memory allocation (512, 1024, 2048, 3072, 4096, 6144, 8192, 10240, 12288)"
  type        = string
  default     = "512"
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

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 3
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Service     = var.name
    ManagedBy   = "terraform"
  }
}

# IAM Role for App Runner to access ECR
resource "aws_iam_role" "ecr_access" {
  name = "${var.name}-ecr-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# IAM Role for App Runner instance (runtime)
resource "aws_iam_role" "instance" {
  name = "${var.name}-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# S3 access for instance
resource "aws_iam_role_policy" "instance_s3" {
  name = "${var.name}-s3-access"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Secrets Manager access for instance
resource "aws_iam_role_policy" "instance_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0
  name  = "${var.name}-secrets-access"
  role  = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = values(var.secrets)
      }
    ]
  })
}

# Auto Scaling Configuration
resource "aws_apprunner_auto_scaling_configuration_version" "main" {
  auto_scaling_configuration_name = var.name

  max_concurrency = 100
  max_size        = var.max_size
  min_size        = var.min_size

  tags = local.common_tags
}

# App Runner Service
resource "aws_apprunner_service" "main" {
  service_name = var.name

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.ecr_access.arn
    }

    image_repository {
      image_identifier      = var.image
      image_repository_type = "ECR"

      image_configuration {
        port = tostring(var.port)

        runtime_environment_variables = var.environment_variables
      }
    }

    auto_deployments_enabled = var.auto_deployments_enabled
  }

  instance_configuration {
    cpu               = var.cpu
    memory            = var.memory
    instance_role_arn = aws_iam_role.instance.arn
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = var.health_check_path
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.main.arn

  dynamic "network_configuration" {
    for_each = var.vpc_connector_arn != null ? [1] : []
    content {
      egress_configuration {
        egress_type       = "VPC"
        vpc_connector_arn = var.vpc_connector_arn
      }
    }
  }

  tags = local.common_tags
}

# Custom Domain Association
resource "aws_apprunner_custom_domain_association" "main" {
  count = var.domain != null ? 1 : 0

  domain_name = var.domain
  service_arn = aws_apprunner_service.main.arn

  enable_www_subdomain = false
}

# Route 53 Record for Custom Domain
resource "aws_route53_record" "main" {
  count = var.domain != null && var.zone_id != null ? 1 : 0

  zone_id = var.zone_id
  name    = var.domain
  type    = "CNAME"
  ttl     = 300
  records = [aws_apprunner_service.main.service_url]
}

# Validation Records (created by App Runner)
resource "aws_route53_record" "validation" {
  for_each = var.domain != null && var.zone_id != null ? {
    for record in aws_apprunner_custom_domain_association.main[0].certificate_validation_records :
    record.name => record
  } : {}

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}

output "service_arn" {
  description = "App Runner service ARN"
  value       = aws_apprunner_service.main.arn
}

output "service_id" {
  description = "App Runner service ID"
  value       = aws_apprunner_service.main.service_id
}

output "service_url" {
  description = "App Runner service URL"
  value       = aws_apprunner_service.main.service_url
}

output "custom_domain" {
  description = "Custom domain (if configured)"
  value       = var.domain
}

output "ecr_access_role_arn" {
  description = "ECR access role ARN"
  value       = aws_iam_role.ecr_access.arn
}

output "instance_role_arn" {
  description = "Instance role ARN"
  value       = aws_iam_role.instance.arn
}

