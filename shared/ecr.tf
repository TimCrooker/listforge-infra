# ECR Repositories - one per app
# These are created per-app by the app-service module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "app_names" {
  description = "List of app names to create ECR repositories for"
  type        = list(string)
  default     = []
}

resource "aws_ecr_repository" "apps" {
  for_each = toset(var.app_names)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = each.value
    ManagedBy   = "terraform"
    Environment = "shared"
  }
}

resource "aws_ecr_lifecycle_policy" "apps" {
  for_each   = toset(var.app_names)
  repository = aws_ecr_repository.apps[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "repository_urls" {
  description = "Map of app name to ECR repository URL"
  value       = { for k, v in aws_ecr_repository.apps : k => v.repository_url }
}

output "registry_id" {
  description = "ECR registry ID"
  value       = length(aws_ecr_repository.apps) > 0 ? values(aws_ecr_repository.apps)[0].registry_id : ""
}

