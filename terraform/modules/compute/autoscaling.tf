# ========================================
# Auto Scaling
# ========================================

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${module.ecs.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.common_tags
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "${var.app_name}-${var.environment}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "${var.app_name}-${var.environment}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# ========================================
# Scheduled Scaling for Off-Hours Cost Savings
# ========================================

# Scale down to minimum capacity after business hours (weekday evenings)
# Default: 6 PM EST Mon-Fri (11 PM UTC)
resource "aws_appautoscaling_scheduled_action" "scale_down_evening" {
  count = var.enable_scheduled_scaling ? 1 : 0

  name               = "${var.app_name}-${var.environment}-scale-down-evening"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = var.scale_down_schedule

  scalable_target_action {
    min_capacity = var.off_hours_min_capacity
    max_capacity = var.off_hours_min_capacity + 1 # Limit scale-out during off-hours
  }
}

# Scale up before business hours (weekday mornings)
# Default: 8 AM EST Mon-Fri (12 PM UTC)
resource "aws_appautoscaling_scheduled_action" "scale_up_morning" {
  count = var.enable_scheduled_scaling ? 1 : 0

  name               = "${var.app_name}-${var.environment}-scale-up-morning"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = var.scale_up_schedule

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity # Full scale-out capacity during business hours
  }
}

# Scale down for weekends
# Default: Saturday 12 AM EST (5 AM UTC)
resource "aws_appautoscaling_scheduled_action" "scale_down_weekend" {
  count = var.enable_scheduled_scaling ? 1 : 0

  name               = "${var.app_name}-${var.environment}-scale-down-weekend"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = var.weekend_scale_down_schedule

  scalable_target_action {
    min_capacity = var.off_hours_min_capacity
    max_capacity = var.off_hours_min_capacity + 1 # Limit scale-out during weekends
  }
}

# ========================================
# Queue Worker Auto Scaling (SQS-driven)
# ========================================

resource "aws_appautoscaling_target" "queue_worker" {
  count = local.queue_worker_autoscaling_enabled ? 1 : 0

  max_capacity       = var.queue_worker_max_capacity
  min_capacity       = var.queue_worker_min_capacity
  resource_id        = "service/${module.ecs.cluster_name}/${aws_ecs_service.worker["queue-worker"].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.common_tags
}

resource "aws_appautoscaling_policy" "queue_worker_age" {
  count = local.queue_worker_autoscaling_enabled ? 1 : 0

  name               = "${var.app_name}-${var.environment}-queue-worker-age-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.queue_worker[0].resource_id
  scalable_dimension = aws_appautoscaling_target.queue_worker[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.queue_worker[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.queue_worker_target_age_seconds

    customized_metric_specification {
      dynamic "metrics" {
        for_each = var.sqs_queue_full_names
        content {
          id          = "m${metrics.key}"
          label       = "AgeOldest_${metrics.value}"
          return_data = false

          metric_stat {
            stat = "Maximum"

            metric {
              namespace   = "AWS/SQS"
              metric_name = "ApproximateAgeOfOldestMessage"

              dimensions {
                name  = "QueueName"
                value = metrics.value
              }
            }
          }
        }
      }

      metrics {
        id          = "max_age"
        label       = "MaxAgeAcrossQueues"
        return_data = true
        expression  = "MAX([${join(",", [for i, _ in var.sqs_queue_full_names : "m${i}"])}])"
      }
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}