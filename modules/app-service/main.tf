# App Service Module - Reusable App Runner Service

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

# S3 access for instance (only created if bucket ARN is provided)
resource "aws_iam_role_policy" "instance_s3" {
  count = var.s3_bucket_arn != null ? 1 : 0
  name  = "${var.name}-s3-access"
  role  = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = ["${var.s3_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.s3_bucket_arn]
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

# Route 53 Records for Custom Domain
# Note: App Runner custom domain association automatically manages DNS records:
# - For apex domains (list-forge.ai): Creates multiple A records
# - For subdomains (api.list-forge.ai): Requires CNAME record pointing to service URL
# 
# The CNAME is only needed for subdomains, and only if not automatically created.
# In practice, App Runner handles both cases, so we don't need to create records manually.
# Keeping this resource commented out to document the behavior.
#
# resource "aws_route53_record" "custom_domain" {
#   count = var.domain != null && var.zone_id != null && !var.is_apex_domain ? 1 : 0
#   zone_id = var.zone_id
#   name    = var.domain
#   type    = "CNAME"
#   ttl     = 300
#   records = [aws_apprunner_service.main.service_url]
# }
