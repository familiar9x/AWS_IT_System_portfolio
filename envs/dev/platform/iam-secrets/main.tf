# Dev Environment - Platform IAM & Secrets
# IAM Roles for ECS/Lambda, Secrets Manager, SSM Parameters

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.default_tags
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.environment}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (application role)
resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.environment}-ecs-task-role"
  }
}

# Allow ECS tasks to read secrets
resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "secrets-access"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:*:secret:${var.environment}/*",
          "arn:aws:ssm:${var.region}:*:parameter/${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.environment}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.environment}-lambda-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Allow Lambda to read secrets
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "secrets-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:*:secret:${var.environment}/*",
          "arn:aws:ssm:${var.region}:*:parameter/${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# Secrets Manager - Database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  for_each = var.applications

  name        = "${var.environment}/${each.key}/db-credentials"
  description = "Database credentials for ${each.key} in ${var.environment}"

  recovery_window_in_days = 0  # Immediate deletion for dev

  tags = {
    Name        = "${var.environment}-${each.key}-db-credentials"
    Application = each.key
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  for_each = var.applications

  secret_id = aws_secretsmanager_secret.db_credentials[each.key].id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password[each.key].result
    engine   = each.value.db_engine
    host     = ""  # Will be updated after RDS creation
    port     = each.value.db_port
    dbname   = each.value.db_name
  })
}

resource "random_password" "db_password" {
  for_each = var.applications

  length  = 16
  special = true
}

# SSM Parameters - Application configs
resource "aws_ssm_parameter" "app_config" {
  for_each = var.applications

  name        = "/${var.environment}/${each.key}/config"
  description = "Application configuration for ${each.key}"
  type        = "String"
  value = jsonencode({
    log_level = "debug"
    features  = {
      feature_a = true
      feature_b = false
    }
  })

  tags = {
    Name        = "${var.environment}-${each.key}-config"
    Application = each.key
  }
}
