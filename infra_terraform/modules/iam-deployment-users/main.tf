# IAM Groups and Users for Environment-based Deployment
# Creates groups with appropriate permissions for dev and prod deployments

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "create_users" {
  description = "Whether to create IAM users"
  type        = bool
  default     = true
}

variable "dev_users" {
  description = "List of usernames for dev environment"
  type        = list(string)
  default     = []
}

variable "prod_users" {
  description = "List of usernames for prod environment (DevOps)"
  type        = list(string)
  default     = []
}

# IAM Group for Dev Environment
resource "aws_iam_group" "dev_deployers" {
  count = var.environment == "dev" ? 1 : 0
  name  = "${var.project_name}-dev-deployers"
  path  = "/developers/"
}

# IAM Group for Prod Environment (DevOps)
resource "aws_iam_group" "prod_deployers" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${var.project_name}-devops-deployers"
  path  = "/devops/"
}

# Policy for Dev Deployers - Limited permissions
resource "aws_iam_group_policy" "dev_deployers" {
  count = var.environment == "dev" ? 1 : 0
  name  = "${var.project_name}-dev-deploy-policy"
  group = aws_iam_group.dev_deployers[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECROperations"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowECSDevOperations"
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:UpdateService",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = "dev"
          }
        }
      },
      {
        Sid    = "AllowS3DevBucketOperations"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-fe-*",
          "arn:aws:s3:::${var.project_name}-fe-*/*"
        ]
      },
      {
        Sid    = "AllowCloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowTerraformStateRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*-terraform-state-*",
          "arn:aws:s3:::*-terraform-state-*/*"
        ]
      },
      {
        Sid    = "AllowDynamoDBStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/*-terraform-state-lock"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "rds:Describe*",
          "elasticloadbalancing:Describe*",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for Prod Deployers (DevOps) - Full deployment permissions
resource "aws_iam_group_policy" "prod_deployers" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${var.project_name}-devops-deploy-policy"
  group = aws_iam_group.prod_deployers[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECRFullAccess"
        Effect = "Allow"
        Action = [
          "ecr:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowECSFullAccess"
        Effect = "Allow"
        Action = [
          "ecs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3FullAccess"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      },
      {
        Sid    = "AllowCloudFrontFullAccess"
        Effect = "Allow"
        Action = [
          "cloudfront:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowTerraformOperations"
        Effect = "Allow"
        Action = [
          "s3:*",
          "dynamodb:*",
          "ec2:*",
          "rds:*",
          "elasticloadbalancing:*",
          "iam:*",
          "lambda:*",
          "apigateway:*",
          "events:*",
          "logs:*",
          "cloudwatch:*",
          "secretsmanager:*",
          "route53:*",
          "acm:*",
          "kms:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach ReadOnlyAccess managed policy to Dev group
resource "aws_iam_group_policy_attachment" "dev_readonly" {
  count      = var.environment == "dev" ? 1 : 0
  group      = aws_iam_group.dev_deployers[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Create IAM Users for Dev Environment
resource "aws_iam_user" "dev_users" {
  count = var.environment == "dev" && var.create_users ? length(var.dev_users) : 0
  name  = var.dev_users[count.index]
  path  = "/developers/"

  tags = {
    Environment = "dev"
    Role        = "Developer"
    ManagedBy   = "Terraform"
  }
}

# Add Dev users to Dev deployers group
resource "aws_iam_user_group_membership" "dev_users" {
  count = var.environment == "dev" && var.create_users ? length(var.dev_users) : 0
  user  = aws_iam_user.dev_users[count.index].name

  groups = [
    aws_iam_group.dev_deployers[0].name
  ]
}

# Create IAM Users for Prod Environment (DevOps)
resource "aws_iam_user" "prod_users" {
  count = var.environment == "prod" && var.create_users ? length(var.prod_users) : 0
  name  = var.prod_users[count.index]
  path  = "/devops/"

  tags = {
    Environment = "prod"
    Role        = "DevOps"
    ManagedBy   = "Terraform"
  }
}

# Add Prod users to Prod deployers group
resource "aws_iam_user_group_membership" "prod_users" {
  count = var.environment == "prod" && var.create_users ? length(var.prod_users) : 0
  user  = aws_iam_user.prod_users[count.index].name

  groups = [
    aws_iam_group.prod_deployers[0].name
  ]
}

# Create access keys for users (optional - better to use AWS SSO)
resource "aws_iam_access_key" "dev_users" {
  count = var.environment == "dev" && var.create_users ? length(var.dev_users) : 0
  user  = aws_iam_user.dev_users[count.index].name
}

resource "aws_iam_access_key" "prod_users" {
  count = var.environment == "prod" && var.create_users ? length(var.prod_users) : 0
  user  = aws_iam_user.prod_users[count.index].name
}

# Outputs
output "dev_group_name" {
  value       = var.environment == "dev" ? aws_iam_group.dev_deployers[0].name : null
  description = "Dev deployers group name"
}

output "prod_group_name" {
  value       = var.environment == "prod" ? aws_iam_group.prod_deployers[0].name : null
  description = "Prod/DevOps deployers group name"
}

output "dev_user_names" {
  value       = var.environment == "dev" && var.create_users ? aws_iam_user.dev_users[*].name : []
  description = "List of created dev user names"
}

output "prod_user_names" {
  value       = var.environment == "prod" && var.create_users ? aws_iam_user.prod_users[*].name : []
  description = "List of created prod/DevOps user names"
}

output "dev_access_keys" {
  value = var.environment == "dev" && var.create_users ? {
    for idx, user in aws_iam_user.dev_users : user.name => {
      access_key_id     = aws_iam_access_key.dev_users[idx].id
      secret_access_key = aws_iam_access_key.dev_users[idx].secret
    }
  } : {}
  description = "Dev users access keys (store securely!)"
  sensitive   = true
}

output "prod_access_keys" {
  value = var.environment == "prod" && var.create_users ? {
    for idx, user in aws_iam_user.prod_users : user.name => {
      access_key_id     = aws_iam_access_key.prod_users[idx].id
      secret_access_key = aws_iam_access_key.prod_users[idx].secret
    }
  } : {}
  description = "Prod/DevOps users access keys (store securely!)"
  sensitive   = true
}
