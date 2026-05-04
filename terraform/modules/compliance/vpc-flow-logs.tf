# ========================================
# VPC Flow Logs (Environment-Specific)
# ========================================

resource "aws_flow_log" "vpc" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  vpc_id               = var.vpc_id
  traffic_type         = var.flow_logs_traffic_type
  log_destination_type = "s3"
  log_destination      = var.vpc_flow_logs_bucket_arn

  destination_options {
    file_format                = "parquet"
    hive_compatible_partitions = true
    per_hour_partition         = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.app_name}-${var.environment}-vpc-flow-logs"
    }
  )
}