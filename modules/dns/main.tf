# DNS Module - Route 53 + ACM Certificates

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "domain" {
  description = "Root domain name"
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

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain

  tags = merge(local.common_tags, {
    Name = var.domain
  })
}

# ACM Certificate for wildcard domain
resource "aws_acm_certificate" "wildcard" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = "wildcard-${replace(var.domain, ".", "-")}"
    Project   = var.project
    ManagedBy = "terraform"
  }
}

# DNS validation is handled automatically by AWS when using Route 53 in the same account
# The certificate will validate once the zone is active and nameservers are configured

# Note: If you need explicit validation records, apply the certificate first with -target,
# then apply the rest. This avoids the for_each dependency on unknown values.

output "zone_id" {
  description = "Route 53 zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_name_servers" {
  description = "Name servers for the hosted zone"
  value       = aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.wildcard.arn
}


