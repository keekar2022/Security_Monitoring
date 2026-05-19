# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

resource "aws_iam_role" "secmon_instance" {
  name_prefix = "${var.project_name}-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "secmon_instance" {
  name_prefix = "${var.project_name}-ec2-"
  role        = aws_iam_role.secmon_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3AppAndMetrics"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.secmon.arn]
      },
      {
        Sid    = "S3Objects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.secmon.arn}/releases/*",
          "${aws_s3_bucket.secmon.arn}/data/*"
        ]
      },
      {
        Sid    = "SecretsRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.app.arn,
          aws_secretsmanager_secret.trendmicro.arn
        ]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/secmon/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secmon_ssm" {
  role       = aws_iam_role.secmon_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "secmon" {
  name_prefix = "${var.project_name}-ec2-"
  role        = aws_iam_role.secmon_instance.name
}
