# ========================================
# Bastion Scheduled Stop/Start
# ========================================

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "bastion_scheduler" {
  count = var.enable_scheduled_stop ? 1 : 0

  name = "${var.app_name}-${var.environment}-bastion-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bastion_scheduler" {
  count = var.enable_scheduled_stop ? 1 : 0

  name = "${var.app_name}-${var.environment}-bastion-scheduler-policy"
  role = aws_iam_role.bastion_scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = aws_instance.bastion.arn
      }
    ]
  })
}

resource "aws_scheduler_schedule" "bastion_stop" {
  count = var.enable_scheduled_stop ? 1 : 0

  name        = "${var.app_name}-${var.environment}-bastion-stop"
  description = "Stop bastion off-hours to reduce compute and public IPv4 cost."

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.stop_schedule
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.bastion_scheduler[0].arn

    input = jsonencode({
      InstanceIds = [aws_instance.bastion.id]
    })
  }
}

resource "aws_scheduler_schedule" "bastion_start" {
  count = var.enable_scheduled_stop ? 1 : 0

  name        = "${var.app_name}-${var.environment}-bastion-start"
  description = "Start bastion before business hours."

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.start_schedule
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.bastion_scheduler[0].arn

    input = jsonencode({
      InstanceIds = [aws_instance.bastion.id]
    })
  }
}
