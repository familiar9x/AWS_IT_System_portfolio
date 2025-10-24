# EventBridge Automated Ingest Module
# Hourly ingest from external systems via ECS RunTask

variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "ecs_cluster_id" { type = string }
variable "ecs_task_definition_arn" { type = string }
variable "ecs_security_group_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

# EventBridge Rule for hourly ingest
resource "aws_cloudwatch_event_rule" "hourly_ingest" {
  name                = "${var.name}-hourly-ingest"
  description         = "Trigger ingest every hour"
  schedule_expression = "cron(0 * * * ? *)" # Every hour at minute 0

  tags = merge(var.tags, {
    Name = "${var.name}-hourly-ingest-rule"
  })
}

# Dead Letter Queue for failed tasks
resource "aws_sqs_queue" "ingest_dlq" {
  name                      = "${var.name}-ingest-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = merge(var.tags, {
    Name = "${var.name}-ingest-dlq"
  })
}

# IAM Role for EventBridge to run ECS tasks
resource "aws_iam_role" "eventbridge_ecs" {
  name = "${var.name}-eventbridge-ecs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-eventbridge-ecs-role"
  })
}

# IAM Policy for EventBridge to run ECS tasks
resource "aws_iam_role_policy" "eventbridge_ecs" {
  name = "${var.name}-eventbridge-ecs-policy"
  role = aws_iam_role.eventbridge_ecs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = var.ecs_task_definition_arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:PassedToService" : "ecs-tasks.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.ingest_dlq.arn
      }
    ]
  })
}

# EventBridge Target - ECS RunTask
resource "aws_cloudwatch_event_target" "ecs_ingest" {
  rule      = aws_cloudwatch_event_rule.hourly_ingest.name
  target_id = "IngestECSTarget"
  arn       = var.ecs_cluster_id
  role_arn  = aws_iam_role.eventbridge_ecs.arn

  ecs_target {
    task_definition_arn = var.ecs_task_definition_arn
    launch_type         = "FARGATE"
    platform_version    = "LATEST"

    network_configuration {
      subnets          = var.private_subnet_ids
      security_groups  = [var.ecs_security_group_id]
      assign_public_ip = false
    }
  }

  # Retry configuration
  retry_policy {
    maximum_retry_attempts       = 3
    maximum_event_age_in_seconds = 3600
  }

  # Dead Letter Queue
  dead_letter_config {
    arn = aws_sqs_queue.ingest_dlq.arn
  }
}

# CloudWatch Log Group for ingest logs
resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/ecs/${var.name}-ingest"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name}-ingest-logs"
  })
}

# Outputs
output "eventbridge_rule_arn" {
  value       = aws_cloudwatch_event_rule.hourly_ingest.arn
  description = "EventBridge rule ARN for ingest"
}

output "dlq_url" {
  value       = aws_sqs_queue.ingest_dlq.url
  description = "Dead Letter Queue URL for failed ingest tasks"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.ingest.name
  description = "CloudWatch log group for ingest tasks"
}
