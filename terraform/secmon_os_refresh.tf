# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

data "archive_file" "os_refresh_lambda" {
  count = var.os_refresh_enabled && local.image_factory_dynamic_lookup ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/secmon_monthly_os_refresh/lambda_function.py"
  output_path = "${path.module}/.lambda/secmon_monthly_os_refresh.zip"
}

resource "aws_iam_role" "os_refresh_lambda" {
  count = var.os_refresh_enabled && local.image_factory_dynamic_lookup ? 1 : 0

  name_prefix = "${var.project_name}-os-refresh-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "os_refresh_lambda" {
  count = var.os_refresh_enabled && local.image_factory_dynamic_lookup ? 1 : 0

  name_prefix = "${var.project_name}-os-refresh-"
  role        = aws_iam_role.os_refresh_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeImages",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:ModifyLaunchTemplate"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:StartInstanceRefresh",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = aws_autoscaling_group.secmon.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${var.project_name}-*"
      }
    ]
  })
}

resource "aws_lambda_function" "os_refresh" {
  count = var.os_refresh_enabled && local.image_factory_dynamic_lookup ? 1 : 0

  function_name = "${var.project_name}-monthly-os-refresh"
  role          = aws_iam_role.os_refresh_lambda[0].arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 300

  filename         = data.archive_file.os_refresh_lambda[0].output_path
  source_code_hash = data.archive_file.os_refresh_lambda[0].output_base64sha256

  environment {
    variables = {
      LAUNCH_TEMPLATE_NAME      = aws_launch_template.secmon.name
      ASG_NAME                  = aws_autoscaling_group.secmon.name
      IMAGE_FACTORY_OWNER_ID    = var.image_factory_owner_id
      IMAGE_FACTORY_AMI_PATTERN = var.image_factory_ami_name_pattern
      INSTANCE_ARCHITECTURE     = var.instance_architecture
      OS_REFRESH_SCALE_OUT      = var.os_refresh_scale_out_temporarily ? "true" : "false"
      ASG_MAX_SIZE              = tostring(var.asg_max_size)
      INSTANCE_WARMUP           = tostring(var.asg_health_check_grace_period)
    }
  }

  depends_on = [aws_iam_role_policy.os_refresh_lambda]
}

resource "aws_cloudwatch_log_group" "os_refresh" {
  count = var.os_refresh_enabled && local.image_factory_dynamic_lookup ? 1 : 0

  name              = "/aws/lambda/${var.project_name}-monthly-os-refresh"
  retention_in_days = 30
}

resource "aws_cloudwatch_event_rule" "os_refresh_thursday" {
  count = var.os_refresh_enabled && local.image_factory_dynamic_lookup ? 1 : 0

  name                = "${var.project_name}-os-refresh-thu"
  description         = "Weekly Thursday trigger; Lambda skips unless day after Patch Tuesday"
  schedule_expression = "cron(0 ${var.os_refresh_utc_hour} ? * THU *)"
}

resource "aws_cloudwatch_event_target" "os_refresh" {
  count = var.os_refresh_enabled && local.image_factory_dynamic_lookup ? 1 : 0

  rule      = aws_cloudwatch_event_rule.os_refresh_thursday[0].name
  target_id = "os-refresh-lambda"
  arn       = aws_lambda_function.os_refresh[0].arn
}

resource "aws_lambda_permission" "os_refresh_eventbridge" {
  count = var.os_refresh_enabled && local.image_factory_dynamic_lookup ? 1 : 0

  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.os_refresh[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.os_refresh_thursday[0].arn
}
