# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

locals {
  account_id = var.aws_account_id != "" ? var.aws_account_id : data.aws_caller_identity.current.account_id

  secmon_ami_id = var.secmon_ami_id != null ? var.secmon_ami_id : (
    var.use_image_factory_ami && local.image_factory_ami_id != null ? local.image_factory_ami_id : local.default_fallback_ami_id
  )
  secmon_ami_id_ok = local.secmon_ami_id != null && local.secmon_ami_id != ""

  # HTTPS when ACM is validated (Route53 auto or manual alb_certificate_ready) or external cert ARN provided
  alb_acm_auto_validate = (
    var.create_alb_certificate && var.alb_domain_name != null && var.route53_zone_id != null
  )
  alb_acm_manual_ready = (
    var.create_alb_certificate && var.alb_domain_name != null && var.alb_certificate_ready
  )
  alb_use_https = local.alb_acm_auto_validate || local.alb_acm_manual_ready || var.alb_ssl_certificate_arn != null

  alb_cert_arn = (
    var.alb_ssl_certificate_arn != null ? var.alb_ssl_certificate_arn :
    (var.create_alb_certificate && var.alb_domain_name != null ? aws_acm_certificate.alb[0].arn : null)
  )

  alb_cert_validation_records = local.alb_acm_auto_validate ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  alb_create_dns_alias = (
    local.alb_use_https && var.alb_domain_name != null && var.route53_zone_id != null && var.create_alb_dns_alias
  )

  secret_app_name        = "${var.project_name}/secmon/app"
  secret_trendmicro_name = "${var.project_name}/secmon/trendmicro"
  s3_bucket              = lower(var.s3_bucket_name)

  user_data = templatefile("${path.module}/templates/secmon-user-data.sh.tftpl", {
    project_name           = var.project_name
    aws_region             = var.aws_region
    s3_bucket              = local.s3_bucket
    app_release_version    = var.secmon_app_release_version
    secret_app_name        = local.secret_app_name
    secret_trendmicro_name = local.secret_trendmicro_name
    user_data_os_update    = var.user_data_os_update ? "true" : "false"
  })
}
