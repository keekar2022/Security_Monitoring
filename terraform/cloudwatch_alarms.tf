# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

variable "enable_cloudwatch_alarms" {
  description = "Create CloudWatch alarms for ALB unhealthy targets and 5xx errors"
  type        = bool
  default     = true
}

resource "aws_sns_topic" "secmon_alarms" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  name_prefix = "${var.project_name}-alarms-"
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_description   = "ALB target group has unhealthy Streamlit instances (502 risk)"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.streamlit.arn_suffix
  }

  alarm_actions = [aws_sns_topic.secmon_alarms[0].arn]
  ok_actions    = [aws_sns_topic.secmon_alarms[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_description   = "Elevated 5xx from Streamlit targets behind ALB"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.streamlit.arn_suffix
  }

  alarm_actions = [aws_sns_topic.secmon_alarms[0].arn]
}

output "cloudwatch_alarm_sns_topic_arn" {
  description = "Subscribe email/Slack to this SNS topic for ALB alarms"
  value       = var.enable_cloudwatch_alarms ? aws_sns_topic.secmon_alarms[0].arn : null
}
