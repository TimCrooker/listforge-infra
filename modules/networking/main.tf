# Networking Module - VPC, Subnets, VPC Connector

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Use default VPC for simplicity (can be changed to custom VPC)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for internal services
resource "aws_security_group" "internal" {
  name        = "${local.name_prefix}-internal"
  description = "Security group for internal services"
  vpc_id      = data.aws_vpc.default.id

  # Allow all inbound from within VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-internal-sg"
  })
}

# VPC Connector for App Runner
resource "aws_apprunner_vpc_connector" "main" {
  vpc_connector_name = "${local.name_prefix}-vpc-connector"
  subnets            = slice(data.aws_subnets.default.ids, 0, min(2, length(data.aws_subnets.default.ids)))
  security_groups    = [aws_security_group.internal.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-connector"
  })
}

output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.default.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = data.aws_vpc.default.cidr_block
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = data.aws_subnets.default.ids
}

output "security_group_id" {
  description = "Internal security group ID"
  value       = aws_security_group.internal.id
}

output "vpc_connector_arn" {
  description = "App Runner VPC Connector ARN"
  value       = aws_apprunner_vpc_connector.main.arn
}

