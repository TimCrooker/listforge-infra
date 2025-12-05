# Production Environment - Main Configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "listforge-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  region       = data.aws_region.current.name
  ecr_registry = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com"
}

# Networking
module "networking" {
  source = "../../modules/networking"

  project     = var.project
  environment = var.environment
}

# DNS
module "dns" {
  source = "../../modules/dns"

  domain      = var.domain
  project     = var.project
  environment = var.environment
}

# Database
module "database" {
  source = "../../modules/database"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.subnet_ids
  security_group_id = module.networking.security_group_id

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
}

# Cache
module "cache" {
  source = "../../modules/cache"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.subnet_ids
  security_group_id = module.networking.security_group_id

  node_type = var.cache_node_type
}

# Storage
module "storage" {
  source = "../../modules/storage"

  project       = var.project
  environment   = var.environment
  bucket_suffix = var.storage_bucket_suffix
}

