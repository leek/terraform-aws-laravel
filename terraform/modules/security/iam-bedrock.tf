# ========================================
# AWS Bedrock IAM (Optional)
# ========================================

locals {
  effective_bedrock_region = var.bedrock_region != "" ? var.bedrock_region : var.aws_region
}

data "aws_iam_policy_document" "bedrock_invoke" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:ListInferenceProfiles"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "bedrock:Converse",
      "bedrock:ConverseStream",
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = ["arn:aws:bedrock:*::foundation-model/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "bedrock:Converse",
      "bedrock:ConverseStream",
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = ["arn:aws:bedrock:${local.effective_bedrock_region}:${var.caller_identity_account_id}:inference-profile/*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_bedrock_policy" {
  count = var.enable_bedrock ? 1 : 0

  name   = "${var.app_name}-${var.environment}-ecs-task-bedrock-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.bedrock_invoke.json
}

resource "aws_iam_user_policy" "laravel_app_user_bedrock_policy" {
  count = var.enable_bedrock ? 1 : 0

  name   = "${var.app_name}-${var.environment}-laravel-user-bedrock-policy"
  user   = aws_iam_user.laravel_app_user.name
  policy = data.aws_iam_policy_document.bedrock_invoke.json
}