# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Optional SSM post-boot checks (OSCAL pattern)

variable "secmon_ssm_post_boot_association_enabled" {
  description = "Periodic SSM association for Streamlit health and optional S3 app sync"
  type        = bool
  default     = true
}

variable "secmon_ssm_release_s3_prefix" {
  description = "Optional S3 prefix for SSM sync into /opt/secmon/app (e.g. releases/2.0.0). Null = releases/<secmon_app_release_version>"
  type        = string
  default     = null
}

locals {
  secmon_ssm_release_prefix = var.secmon_ssm_release_s3_prefix != null ? trim(var.secmon_ssm_release_s3_prefix, "/") : "releases/${var.secmon_app_release_version}"
  secmon_ssm_shell_lines = concat(
    [
      "#!/bin/bash",
      "set -e",
      "systemctl is-active secmon-streamlit >/dev/null 2>&1 && echo secmon-ssm: streamlit active || echo secmon-ssm: streamlit not active",
    ],
    local.secmon_ssm_release_prefix != "" ? [
      "aws s3 sync \"s3://${aws_s3_bucket.secmon.id}/${local.secmon_ssm_release_prefix}/\" /opt/secmon/app/ || true",
    ] : []
  )
}

resource "aws_ssm_document" "secmon_post_boot" {
  count = var.secmon_ssm_post_boot_association_enabled ? 1 : 0

  name          = "${var.project_name}-secmon-post-boot"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Security Monitoring: verify Streamlit, optional S3 app sync"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "PostBoot"
      inputs = { runCommand = [join("\n", local.secmon_ssm_shell_lines)] }
    }]
  })
}

resource "aws_ssm_association" "secmon_post_boot" {
  count = var.secmon_ssm_post_boot_association_enabled ? 1 : 0

  name                        = aws_ssm_document.secmon_post_boot[0].name
  association_name            = "${var.project_name}-secmon-post-boot"
  schedule_expression         = "rate(30 minutes)"
  apply_only_at_cron_interval = false
  compliance_severity         = "LOW"

  targets {
    key    = "tag:SECMON_SSM_TARGET"
    values = ["true"]
  }
  targets {
    key    = "tag:Stack"
    values = [var.project_name]
  }
}
