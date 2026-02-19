# ========================================
# SQS Queues for Laravel Jobs
# ========================================

locals {
  sqs_suffix = "-${var.app_name}-${var.environment}"
}

# Shared dead letter queue for failed jobs
resource "aws_sqs_queue" "deadletter" {
  name                              = "deadletter${local.sqs_suffix}"
  delay_seconds                     = 0
  max_message_size                  = 262144
  message_retention_seconds         = 1209600 # 14 days
  receive_wait_time_seconds         = 20
  kms_master_key_id                 = var.sqs_kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.common_tags, {
    Name = "deadletter${local.sqs_suffix}"
  })
}

# Application queues (one per logical queue name)
resource "aws_sqs_queue" "queues" {
  for_each = toset(var.queue_names)

  name                              = "${each.key}${local.sqs_suffix}"
  delay_seconds                     = 0
  max_message_size                  = 262144
  message_retention_seconds         = 1209600 # 14 days
  receive_wait_time_seconds         = 20      # Long polling
  visibility_timeout_seconds        = 300     # 5 minutes
  kms_master_key_id                 = var.sqs_kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.common_tags, {
    Name = "${each.key}${local.sqs_suffix}"
  })
}
