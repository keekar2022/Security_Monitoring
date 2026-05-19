# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# PCL: no 0.0.0.0/0 on ingress

resource "aws_security_group" "alb" {
  name_prefix            = "${var.project_name}-alb-"
  description            = "ALB for Security Monitoring Streamlit"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  # HTTPS listener (when ACM / alb_ssl_certificate_arn is configured)
  dynamic "ingress" {
    for_each = local.alb_use_https ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.default_allowed_cidr_blocks
      description = "HTTPS from allowed CIDRs"
    }
  }

  # Port 80 — HTTP forward (no TLS) or redirect to HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.default_allowed_cidr_blocks
    description = "HTTP from allowed CIDRs (forward or redirect to HTTPS)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "secmon" {
  name_prefix            = "${var.project_name}-instance-"
  description            = "Security Monitoring EC2 (Streamlit + collectors)"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  ingress {
    from_port       = 8501
    to_port         = 8501
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Streamlit from ALB only"
  }

  dynamic "ingress" {
    for_each = var.key_name != null ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.default_allowed_cidr_blocks
      description = "SSH from allowed CIDRs"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Trend Micro, Okta, S3, Secrets Manager"
  }

  lifecycle {
    create_before_destroy = true
  }
}
