variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "rds_sg_id" { type = string }
variable "db_secret_arn" { type = string }
variable "tags" { type = map(string) default = {} }

# ECR Repository for AI Lambda
resource "aws_ecr_repository" "ai_lambda" {
  name                 = "${var.name}-ai-assistant"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.name}-ai-assistant-ecr"
  })
}

# Security Group for AI Lambda
resource "aws_security_group" "ai_lambda" {
  name        = "${var.name}-ai-lambda-sg"
  description = "Security group for AI Lambda function"
  vpc_id      = var.vpc_id

  # Outbound to RDS
  egress {
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [var.rds_sg_id]
    description     = "SQL Server to RDS"
  }

  # Outbound HTTPS for AWS services
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS services"
  }

  # Outbound HTTP for package downloads
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-ai-lambda-sg"
  })
}

# Allow Lambda to access RDS
resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 1433
  to_port                  = 1433
  protocol                 = "tcp"
  security_group_id        = var.rds_sg_id
  source_security_group_id = aws_security_group.ai_lambda.id
  description              = "Allow AI Lambda to access RDS"
}

# IAM Role for Lambda
resource "aws_iam_role" "ai_lambda_role" {
  name = "${var.name}-ai-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "ai_lambda_policy" {
  name = "${var.name}-ai-lambda-policy"
  role = aws_iam_role.ai_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.db_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
          "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
        ]
      }
    ]
  })
}

# Lambda Function (placeholder - will be updated after ECR image push)
resource "aws_lambda_function" "ai_assistant" {
  function_name = "${var.name}-ai-assistant"
  role         = aws_iam_role.ai_lambda_role.arn
  
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.ai_lambda.repository_url}:latest"
  
  timeout     = 60
  memory_size = 512
  
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.ai_lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_NAME = split(":", var.db_secret_arn)[6]
    }
  }

  depends_on = [
    aws_iam_role_policy.ai_lambda_policy,
    aws_cloudwatch_log_group.ai_lambda
  ]

  tags = merge(var.tags, {
    Name = "${var.name}-ai-assistant"
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ai_lambda" {
  name              = "/aws/lambda/${var.name}-ai-assistant"
  retention_in_days = 30

  tags = var.tags
}

# API Gateway
resource "aws_apigatewayv2_api" "ai_api" {
  name          = "${var.name}-ai-api"
  protocol_type = "HTTP"
  description   = "AI Assistant API for CMDB"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type", "x-amz-date", "authorization", "x-api-key"]
    allow_methods     = ["POST", "OPTIONS"]
    allow_origins     = ["*"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }

  tags = var.tags
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "ai_lambda_integration" {
  api_id             = aws_apigatewayv2_api.ai_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.ai_assistant.invoke_arn
}

# API Gateway Route
resource "aws_apigatewayv2_route" "ai_ask_route" {
  api_id    = aws_apigatewayv2_api.ai_api.id
  route_key = "POST /ask"
  target    = "integrations/${aws_apigatewayv2_integration.ai_lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "ai_api_stage" {
  api_id      = aws_apigatewayv2_api.ai_api.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      path          = "$context.path"
      status        = "$context.status"
      responseTime  = "$context.responseTime"
      error         = "$context.error.message"
    })
  }

  tags = var.tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name}-ai-api"
  retention_in_days = 30

  tags = var.tags
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_assistant.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ai_api.execution_arn}/*/*"
}

# VPC Endpoints for Lambda (if no NAT Gateway)
resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true
  
  tags = merge(var.tags, {
    Name = "${var.name}-secretsmanager-endpoint"
  })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true
  
  tags = merge(var.tags, {
    Name = "${var.name}-logs-endpoint"
  })
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ai_lambda.id]
    description     = "HTTPS from Lambda"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-endpoints-sg"
  })
}

# Data sources
data "aws_region" "current" {}

# Outputs
output "api_gateway_url" {
  value = "${aws_apigatewayv2_api.ai_api.api_endpoint}/prod"
  description = "API Gateway URL for AI Assistant"
}

output "api_gateway_domain" {
  value = replace(aws_apigatewayv2_api.ai_api.api_endpoint, "https://", "")
  description = "API Gateway domain name for CloudFront origin"
}

output "ask_endpoint" {
  value = "${aws_apigatewayv2_api.ai_api.api_endpoint}/prod/ask"
  description = "AI Ask endpoint URL"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.ai_lambda.repository_url
  description = "ECR repository URL for AI Lambda"
}

output "lambda_function_name" {
  value = aws_lambda_function.ai_assistant.function_name
  description = "Lambda function name"
}
