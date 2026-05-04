# ========================================
# IAM Access Analyzer (Production Only)
# ========================================

resource "aws_accessanalyzer_analyzer" "main" {
  count = var.enable_access_analyzer && var.environment == "production" ? 1 : 0

  analyzer_name = "${var.app_name}-access-analyzer"
  type          = "ACCOUNT"

  tags = var.common_tags
}