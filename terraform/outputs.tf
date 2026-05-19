# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

output "aws_account_id" {
  value = local.account_id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.secmon.id
}

output "asg_name" {
  value = aws_autoscaling_group.secmon.name
}

output "launch_template_id" {
  value = aws_launch_template.secmon.id
}

output "launch_template_name" {
  value = aws_launch_template.secmon.name
}

output "secret_app_arn" {
  value = aws_secretsmanager_secret.app.arn
}

output "secret_trendmicro_arn" {
  value = aws_secretsmanager_secret.trendmicro.arn
}

output "secmon_ami_id" {
  value = local.secmon_ami_id
}

output "target_group_arn" {
  value = aws_lb_target_group.streamlit.arn
}
