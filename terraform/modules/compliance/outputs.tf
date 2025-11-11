# ========================================
# Compliance Module Outputs
# ========================================

# AWS Config
output "config_recorder_id" {
  description = "ID of the AWS Config recorder"
  value       = var.enable_aws_config && var.environment == "production" ? aws_config_configuration_recorder.main[0].id : null
}

output "config_role_arn" {
  description = "ARN of the AWS Config IAM role"
  value       = var.enable_aws_config && var.environment == "production" ? aws_iam_role.config[0].arn : null
}

# Security Hub
output "security_hub_account_id" {
  description = "AWS Security Hub account ID"
  value       = var.enable_security_hub && var.environment == "production" ? aws_securityhub_account.main[0].id : null
}

output "security_hub_findings_topic_arn" {
  description = "SNS topic ARN for Security Hub findings"
  value       = var.enable_security_hub && length(var.security_hub_notification_emails) > 0 && var.environment == "production" ? aws_sns_topic.security_hub_findings[0].arn : null
}

# GuardDuty
output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_guardduty && var.environment == "production" ? data.aws_guardduty_detector.existing[0].id : null
}

output "guardduty_findings_topic_arn" {
  description = "SNS topic ARN for GuardDuty findings"
  value       = var.enable_guardduty && length(var.guardduty_notification_emails) > 0 && var.environment == "production" ? aws_sns_topic.guardduty_findings[0].arn : null
}

# Macie
output "macie_account_id" {
  description = "AWS Macie account ID"
  value       = var.enable_macie && var.environment == "production" ? aws_macie2_account.main[0].id : null
}

# Access Analyzer
output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer"
  value       = var.enable_access_analyzer && var.environment == "production" ? aws_accessanalyzer_analyzer.main[0].arn : null
}

# AWS Backup
output "backup_vault_arn" {
  description = "ARN of the AWS Backup vault"
  value       = var.enable_backup_audit_manager && var.environment == "production" ? aws_backup_vault.main[0].arn : null
}

output "backup_plan_id" {
  description = "ID of the AWS Backup plan"
  value       = var.enable_backup_audit_manager && var.environment == "production" ? aws_backup_plan.daily[0].id : null
}

output "backup_framework_arn" {
  description = "ARN of the AWS Backup audit framework"
  value       = var.enable_backup_audit_manager && var.enable_hipaa_framework && var.environment == "production" ? aws_backup_framework.hipaa[0].arn : null
}

output "backup_report_plan_arn" {
  description = "ARN of the AWS Backup report plan"
  value       = var.enable_backup_audit_manager && var.environment == "production" ? aws_backup_report_plan.daily[0].arn : null
}

output "restore_testing_plan_name" {
  description = "Name of the AWS Backup restore testing plan"
  value       = var.enable_backup_audit_manager && var.environment == "production" ? aws_backup_restore_testing_plan.weekly[0].name : null
}

# VPC Flow Logs
output "vpc_flow_log_id" {
  description = "ID of the VPC flow log"
  value       = var.enable_vpc_flow_logs ? aws_flow_log.vpc[0].id : null
}
