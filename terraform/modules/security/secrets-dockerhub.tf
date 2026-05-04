# ========================================
# Docker Hub Registry Credentials (Optional)
# ========================================

locals {
  create_dockerhub_secret = var.dockerhub_username != "" && var.dockerhub_access_token != ""
}

resource "aws_secretsmanager_secret" "dockerhub" {
  count = local.create_dockerhub_secret ? 1 : 0

  name        = "${var.app_name}-${var.environment}-dockerhub"
  description = "Docker Hub credentials for ECS repositoryCredentials"
  kms_key_id  = aws_kms_key.main["secrets"].arn

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-dockerhub"
  })
}

resource "aws_secretsmanager_secret_version" "dockerhub" {
  count = local.create_dockerhub_secret ? 1 : 0

  secret_id = aws_secretsmanager_secret.dockerhub[0].id
  secret_string = jsonencode({
    username = var.dockerhub_username
    password = var.dockerhub_access_token
  })
}

data "aws_iam_policy_document" "ecs_execution_dockerhub" {
  count = local.create_dockerhub_secret ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.dockerhub[0].arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.main["secrets"].arn]
  }
}

resource "aws_iam_role_policy" "ecs_execution_role_dockerhub_policy" {
  count = local.create_dockerhub_secret ? 1 : 0

  name   = "${var.app_name}-${var.environment}-ecs-execution-dockerhub-policy"
  role   = aws_iam_role.ecs_execution_role.id
  policy = data.aws_iam_policy_document.ecs_execution_dockerhub[0].json
}
