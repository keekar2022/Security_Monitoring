# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
# Secret shells only — populate values out-of-band (console/CLI)

resource "aws_secretsmanager_secret" "app" {
  name                    = local.secret_app_name
  description             = "Streamlit/Okta/admin settings for Security Monitoring"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret" "trendmicro" {
  name                    = local.secret_trendmicro_name
  description             = "Trend Micro API tokens per environment"
  recovery_window_in_days = 7
}

# Placeholder JSON; replace via AWS Console or:
# aws secretsmanager put-secret-value --secret-id <arn> --secret-string file://secret.json
resource "aws_secretsmanager_secret_version" "app_placeholder" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    OKTA_DOMAIN             = "REPLACE_ME.okta.com"
    OKTA_CLIENT_ID          = "REPLACE_ME"
    OKTA_CLIENT_SECRET      = "REPLACE_ME"
    STREAMLIT_APP_URL       = "https://REPLACE_ME/"
    SETTINGS_ADMIN_USER     = "admin"
    SETTINGS_ADMIN_PASSWORD = "CHANGE_ME"
    COLLECTION_FREQUENCY    = "daily"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "trendmicro_placeholder" {
  secret_id = aws_secretsmanager_secret.trendmicro.id
  secret_string = jsonencode({
    TRENDMICRO_PRODUCTION_API_TOKEN    = "REPLACE_ME"
    TRENDMICRO_PRODUCTION_AU_API_TOKEN = "REPLACE_ME"
    TRENDMICRO_QUALITY_TEST_API_TOKEN  = "REPLACE_ME"
    TRENDMICRO_AMS_QTE_API_TOKEN       = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
