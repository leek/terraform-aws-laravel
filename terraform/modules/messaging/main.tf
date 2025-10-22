# ========================================
# SQS Queue for Laravel Jobs
# ========================================


# Dead letter queue for failed jobs
resource "aws_sqs_queue" "deadletter" {
  name                              = "${var.app_name}-${var.environment}-deadletter"
  delay_seconds                     = 0
  max_message_size                  = 262144
  message_retention_seconds         = 1209600 # 14 days
  receive_wait_time_seconds         = 20
  kms_master_key_id                 = var.sqs_kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-deadletter"
  })
}

# Main application queue
resource "aws_sqs_queue" "main" {
  name                              = "${var.app_name}-${var.environment}-queue"
  delay_seconds                     = 0
  max_message_size                  = 262144
  message_retention_seconds         = 1209600 # 14 days
  receive_wait_time_seconds         = 20      # Long polling
  visibility_timeout_seconds        = 300     # 5 minutes
  kms_master_key_id                 = var.sqs_kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  # Dead letter queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-queue"
  })
}