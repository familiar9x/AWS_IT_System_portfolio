# Foundation: Tag Reconciler Lambda
# Định kỳ reconcile tag ↔ AppRegistry

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "tag_reconciler" {
  name = "tag-reconciler-lambda-role"

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
    Name        = "Tag Reconciler Lambda Role"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.tag_reconciler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "tag_reconciler" {
  name = "tag-reconciler-policy"
  role = aws_iam_role.tag_reconciler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "servicecatalog:*",
          "resource-explorer-2:Search",
          "resource-explorer-2:GetIndex",
          "config:DescribeConfigurationRecorders",
          "config:ListDiscoveredResources",
          "tag:GetResources",
          "tag:GetTagKeys",
          "tag:GetTagValues"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/code.py"
  output_path = "${path.module}/lambda/function.zip"
}

resource "aws_lambda_function" "tag_reconciler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "tag-reconciler"
  role            = aws_iam_role.tag_reconciler.arn
  handler         = "code.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      RESOURCE_EXPLORER_VIEW_ARN = var.resource_explorer_view_arn
    }
  }

  tags = {
    Name        = "Tag Reconciler"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }
}

# EventBridge Scheduler (chạy mỗi 6 giờ)
resource "aws_cloudwatch_event_rule" "tag_reconciler_schedule" {
  name                = "tag-reconciler-schedule"
  description         = "Trigger tag reconciler every 6 hours"
  schedule_expression = "rate(6 hours)"

  tags = {
    Name        = "Tag Reconciler Schedule"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_event_target" "tag_reconciler" {
  rule      = aws_cloudwatch_event_rule.tag_reconciler_schedule.name
  target_id = "TagReconcilerLambda"
  arn       = aws_lambda_function.tag_reconciler.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tag_reconciler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.tag_reconciler_schedule.arn
}
