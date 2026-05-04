# ========================================
# GitHub Actions IAM
# ========================================

# Get existing GitHub OIDC provider if not creating it
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# GitHub OIDC Provider (conditional - only create once per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-github-oidc"
  })
}

# GitHub Actions Role
resource "aws_iam_role" "github_actions" {
  name = "${var.app_name}-${var.environment}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.environment}-github-actions-role"
  })
}

resource "aws_iam_role_policy" "github_actions_policy" {
  name = "${var.app_name}-${var.environment}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR - Docker image push/pull
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*" # Required for ECR login
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${var.caller_identity_account_id}:repository/${var.app_name}-${var.environment}",
          "arn:aws:ecr:${var.aws_region}:${var.caller_identity_account_id}:repository/${var.app_name}-${var.environment}-*"
        ]
      },
      # ECS - Actions that require wildcard resource
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*" # These actions don't support resource-level permissions
      },
      # ECS - Service deployment and task execution with specific resources
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:UpdateService",
          "ecs:RunTask"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:service/${var.app_name}-${var.environment}/*",
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:task/${var.app_name}-${var.environment}/*",
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:task-definition/${var.app_name}-${var.environment}:*",
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:task-definition/${var.app_name}-${var.environment}-*:*",
          "arn:aws:ecs:${var.aws_region}:${var.caller_identity_account_id}:cluster/${var.app_name}-${var.environment}"
        ]
      },
      # CloudWatch Logs - Read deployment logs for debugging
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.caller_identity_account_id}:log-group:/aws/ecs/${var.app_name}-${var.environment}:*"
        ]
      },
      # IAM PassRole - Allow ECS to assume execution and task roles
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}