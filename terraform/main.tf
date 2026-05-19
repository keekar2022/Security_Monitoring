# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# Security Monitoring dashboard — AWS EC2 ASG + ALB + S3 + Secrets Manager
# Patterns aligned with keekar2022/OSCAL-Reports terraform/

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Project      = var.project_name
      Environment  = var.environment
      ManagedBy    = "terraform"
      Stack        = var.project_name
      "Service ID" = var.adobe_service_id_tag
    })
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
