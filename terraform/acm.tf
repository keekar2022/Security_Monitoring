# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
#
# ACM for ALB TLS:
# - **Preferred (AMS policy):** import Let's Encrypt — set alb_ssl_certificate_arn only (create_alb_certificate=false).
#   Use scripts/tls/renew_le_import_acm.sh
# - **Optional:** ACM DNS validation (create_alb_certificate=true) when policy allows issuance.

resource "aws_acm_certificate" "alb" {
  count = var.create_alb_certificate && var.alb_domain_name != null ? 1 : 0

  domain_name               = var.alb_domain_name
  subject_alternative_names = var.alb_certificate_subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-alb-tls"
  }
}

resource "aws_route53_record" "alb_cert_validation" {
  for_each = local.alb_cert_validation_records

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "alb" {
  count = local.alb_acm_auto_validate ? 1 : 0

  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for r in aws_route53_record.alb_cert_validation : r.fqdn]

  timeouts {
    create = "45m"
  }
}

resource "aws_route53_record" "alb_alias" {
  count = local.alb_create_dns_alias ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.alb_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "alb_alias_ipv6" {
  count = local.alb_create_dns_alias && var.alb_dns_alias_ipv6 ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.alb_domain_name
  type    = "AAAA"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

output "acm_certificate_validation_records" {
  description = "Manual DNS path: add these CNAME records, then set alb_certificate_ready = true and re-apply"
  value = var.create_alb_certificate && var.alb_domain_name != null && var.route53_zone_id == null ? [
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : []
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (after validation)"
  value       = try(aws_acm_certificate.alb[0].arn, null)
}

output "app_https_url" {
  description = "Dashboard URL when HTTPS is enabled"
  value = local.alb_use_https && var.alb_domain_name != null ? "https://${var.alb_domain_name}/" : (
    local.alb_use_https ? "https://${aws_lb.main.dns_name}/" : "http://${aws_lb.main.dns_name}/"
  )
}
