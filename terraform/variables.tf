# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID for ARNs"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (stg, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Resource naming prefix"
  type        = string
  default     = "ams-secmon"
}

variable "adobe_service_id_tag" {
  description = "Adobe CMDB Service ID tag value"
  type        = string
  default     = "602844"
}

variable "common_tags" {
  description = "Extra tags merged into default_tags"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "Dedicated VPC CIDR"
  type        = string
  default     = "10.42.0.0/16"
}

variable "default_allowed_cidr_blocks" {
  description = "Ingress CIDR allow list (no 0.0.0.0/0 per PCL)"
  type        = list(string)
  default     = ["130.248.32.17/32", "203.191.182.150/32"]

  validation {
    condition     = !contains(var.default_allowed_cidr_blocks, "0.0.0.0/0")
    error_message = "default_allowed_cidr_blocks must not contain 0.0.0.0/0."
  }
}

variable "key_name" {
  description = "Optional EC2 key pair; null = SSM only"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "instance_architecture" {
  description = "arm64 or x86_64 (must match instance_type and AMI)"
  type        = string
  default     = "x86_64"
}

variable "secmon_ami_id" {
  description = "Override AMI; null = Image Factory or AL2023 fallback"
  type        = string
  default     = null
}

variable "use_image_factory_ami" {
  type    = bool
  default = true
}

variable "image_factory_owner_id" {
  description = "Image Factory AWS account that owns shared AMIs. Required only when image_factory_enable_dynamic_lookup is true."
  type        = string
  default     = null
}

variable "image_factory_enable_dynamic_lookup" {
  description = "Query EC2 for latest Image Factory AMI by owner + name pattern. Leave false unless AMIs are shared into this account; use image_factory_amazon_linux_ami_us_east_1 to pin instead."
  type        = bool
  default     = false
}

variable "image_factory_ami_name_pattern" {
  type    = string
  default = "*Amazon*Linux*2023*EMR*"
}

variable "image_factory_amazon_linux_ami_us_east_1" {
  type    = string
  default = null
}

variable "s3_bucket_name" {
  description = "Globally unique S3 bucket (lowercase); app releases + metrics"
  type        = string
}

variable "secmon_app_release_version" {
  description = "S3 prefix releases/<version>/ synced at boot"
  type        = string
  default     = "2.0.0"
}

variable "asg_min_size" {
  description = "Minimum instances (2 recommended for HA across AZs)"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  description = "Running instances (2 recommended for HA)"
  type        = number
  default     = 2
}

variable "asg_health_check_grace_period" {
  description = "Seconds before ELB health checks affect ASG (allow pip install + Streamlit start)"
  type        = number
  default     = 600
}

variable "user_data_os_update" {
  description = "If true, dnf update in user_data (emergency only; OS refresh uses new AMI)"
  type        = bool
  default     = false
}

variable "alb_allow_http_for_testing" {
  description = "Deprecated: port 80 is always open (HTTP forward or redirect to HTTPS). Kept for compatibility."
  type        = bool
  default     = true
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for alb_domain_name. When set, ACM DNS validation and optional ALB alias are created automatically."
  type        = string
  default     = null
}

variable "create_alb_dns_alias" {
  description = "Create Route53 A/AAAA alias record pointing alb_domain_name to the ALB (requires route53_zone_id)"
  type        = bool
  default     = true
}

variable "alb_dns_alias_ipv6" {
  description = "Also create AAAA alias for the ALB (dual-stack)"
  type        = bool
  default     = false
}

variable "alb_certificate_subject_alternative_names" {
  description = "Optional ACM SANs (e.g. www.example.com)"
  type        = list(string)
  default     = []
}

variable "alb_port_justification" {
  type    = string
  default = "Security Monitoring Streamlit dashboard HTTPS access for AMS Gov Cloud"
}

variable "create_alb_certificate" {
  description = "Request a new cert from ACM (DNS validation). Set false when policy requires Let's Encrypt + import via alb_ssl_certificate_arn."
  type        = bool
  default     = false
}

variable "alb_domain_name" {
  description = "Hostname for ACM request path only (not used for imported certs)"
  type        = string
  default     = null
}

variable "alb_certificate_ready" {
  description = "Manual DNS path only: set true after adding acm_certificate_validation_records CNAMEs in your DNS"
  type        = bool
  default     = false
}

variable "alb_ssl_certificate_arn" {
  description = "Imported ACM certificate ARN (Let's Encrypt via scripts/tls/renew_le_import_acm.sh). Preferred for AMS_1590-STG."
  type        = string
  default     = null
}

variable "alb_ssl_policy" {
  type    = string
  default = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
}

variable "os_refresh_enabled" {
  type    = bool
  default = true
}

variable "os_refresh_utc_hour" {
  description = "Hour (UTC) for Thursday EventBridge trigger"
  type        = number
  default     = 6
}

variable "os_refresh_scale_out_temporarily" {
  description = "Bump ASG desired to max before refresh for zero-downtime"
  type        = bool
  default     = true
}
