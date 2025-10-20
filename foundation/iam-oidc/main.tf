# Foundation: IAM OIDC Provider for GitHub Actions
# Cho phép GitHub Actions assume IAM roles không cần credentials tĩnh

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = {
    Name        = "GitHub Actions OIDC Provider"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }
}

# IAM Role for Dev Environment
resource "aws_iam_role" "github_actions_dev" {
  name = "dev-terraform-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/develop"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "dev-terraform-deploy"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_dev" {
  role       = aws_iam_role.github_actions_dev.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# IAM Role for stg Environment
resource "aws_iam_role" "github_actions_stg" {
  name = "stg-terraform-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/staging"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "stg-terraform-deploy"
    Environment = "stg"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_stg" {
  role       = aws_iam_role.github_actions_stg.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# IAM Role for Production Environment
resource "aws_iam_role" "github_actions_prod" {
  name = "prod-terraform-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "prod-terraform-deploy"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_prod" {
  role       = aws_iam_role.github_actions_prod.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
