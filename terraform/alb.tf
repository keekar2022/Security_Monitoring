# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  idle_timeout       = 300

  tags = {
    "Adobe:PublicPorts"       = local.alb_use_https ? "443" : "80"
    "Adobe:PortJustification" = var.alb_port_justification
  }
}

resource "aws_lb_target_group" "streamlit" {
  name     = "${var.project_name}-st"
  port     = 8501
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/_stcore/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 15
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http_forward" {
  count = local.alb_use_https ? 0 : 1

  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.streamlit.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  count = local.alb_use_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count = local.alb_use_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = local.alb_cert_arn

  mutual_authentication {
    mode = "off"
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.streamlit.arn
  }

  # When route53_zone_id is set, wait for ACM validation before attaching the cert.
  depends_on = [aws_acm_certificate_validation.alb]
}
