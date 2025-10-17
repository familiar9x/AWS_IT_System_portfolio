# Dev - Backoffice Application Stack
# Lambda + API Gateway + DynamoDB + X-Ray

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state-123456789012"
    key            = "dev/apps-backoffice/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "dev"
      System      = "backoffice"
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources - Get platform outputs
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "dev/platform-iam-secrets/terraform.tfstate"
    region = var.region
  }
}

# AppRegistry Application
resource "aws_servicecatalogappregistry_application" "backoffice" {
  name        = "backoffice-${var.environment}"
  description = "Backoffice Application - ${upper(var.environment)} Environment"

  tags = {
    Name        = "backoffice-${var.environment}"
    System      = "backoffice"
    Environment = var.environment
    Owner       = var.owner
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "backoffice" {
  name           = "${var.environment}-backoffice-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name            = "${var.environment}-backoffice-data"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}

# S3 Bucket for Lambda artifacts
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${var.environment}-backoffice-lambda-artifacts"

  tags = {
    Name            = "${var.environment}-backoffice-lambda-artifacts"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "api_handler" {
  name              = "/aws/lambda/${var.environment}-backoffice-api"
  retention_in_days = 7

  tags = {
    Name            = "${var.environment}-backoffice-api-logs"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}

# Lambda Function - API Handler
resource "aws_lambda_function" "api_handler" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.environment}-backoffice-api"
  role            = data.terraform_remote_state.iam.outputs.lambda_execution_role_arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime         = "python3.11"
  architectures   = ["arm64"]  # 20% cheaper
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.backoffice.name
      ENVIRONMENT    = var.environment
      LOG_LEVEL      = "DEBUG"
    }
  }

  tracing_config {
    mode = "Active"  # Enable X-Ray
  }

  tags = {
    Name            = "${var.environment}-backoffice-api"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }

  depends_on = [aws_cloudwatch_log_group.api_handler]
}

# Lambda Function Code
data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<-EOT
import json
import os
import boto3
from datetime import datetime
import logging

# Setup logging
logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

# DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

def handler(event, context):
    """
    Main Lambda handler for Backoffice API
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Parse request
    http_method = event.get('httpMethod', event.get('requestContext', {}).get('http', {}).get('method'))
    path = event.get('path', event.get('rawPath', '/'))
    
    try:
        if http_method == 'GET' and path == '/health':
            return response(200, {'status': 'healthy', 'service': 'backoffice'})
        
        elif http_method == 'GET' and path == '/items':
            items = get_items()
            return response(200, {'items': items})
        
        elif http_method == 'POST' and path == '/items':
            body = json.loads(event.get('body', '{}'))
            item = create_item(body)
            return response(201, {'item': item})
        
        elif http_method == 'GET' and path.startswith('/items/'):
            item_id = path.split('/')[-1]
            item = get_item(item_id)
            if item:
                return response(200, {'item': item})
            return response(404, {'error': 'Item not found'})
        
        else:
            return response(404, {'error': 'Not found'})
    
    except Exception as e:
        logger.error(f"Error: {str(e)}", exc_info=True)
        return response(500, {'error': 'Internal server error'})

def get_items():
    """Get all items"""
    result = table.scan(Limit=100)
    return result.get('Items', [])

def get_item(item_id):
    """Get single item by ID"""
    result = table.get_item(Key={'id': item_id, 'timestamp': 0})
    return result.get('Item')

def create_item(data):
    """Create new item"""
    item = {
        'id': data.get('id', str(datetime.now().timestamp())),
        'timestamp': int(datetime.now().timestamp()),
        'status': data.get('status', 'pending'),
        'data': data
    }
    table.put_item(Item=item)
    return item

def response(status_code, body):
    """Create HTTP response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body, default=str)
    }
EOT
    filename = "index.py"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.backoffice.execution_arn}/*/*"
}

# IAM Policy for Lambda to access DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.environment}-backoffice-lambda-dynamodb"
  role = split("/", data.terraform_remote_state.iam.outputs.lambda_execution_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.backoffice.arn,
          "${aws_dynamodb_table.backoffice.arn}/index/*"
        ]
      }
    ]
  })
}

# API Gateway HTTP API (v2)
resource "aws_apigatewayv2_api" "backoffice" {
  name          = "${var.environment}-backoffice-api"
  protocol_type = "HTTP"
  description   = "Backoffice API - ${var.environment}"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name            = "${var.environment}-backoffice-api"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.backoffice.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }

  tags = {
    Name            = "${var.environment}-backoffice-api-stage"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.environment}-backoffice"
  retention_in_days = 7

  tags = {
    Name            = "${var.environment}-backoffice-api-logs"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.backoffice.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api_handler.invoke_arn

  payload_format_version = "2.0"
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.backoffice.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_items" {
  api_id    = aws_apigatewayv2_api.backoffice.id
  route_key = "GET /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "create_item" {
  api_id    = aws_apigatewayv2_api.backoffice.id
  route_key = "POST /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_item" {
  api_id    = aws_apigatewayv2_api.backoffice.id
  route_key = "GET /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.environment}-backoffice-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Lambda function errors are too high"

  dimensions = {
    FunctionName = aws_lambda_function.api_handler.function_name
  }

  tags = {
    Name            = "${var.environment}-backoffice-lambda-alarm"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.environment}-backoffice-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Lambda function throttling detected"

  dimensions = {
    FunctionName = aws_lambda_function.api_handler.function_name
  }

  tags = {
    Name            = "${var.environment}-backoffice-throttle-alarm"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.environment}-backoffice-api-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "API Gateway 5xx errors are too high"

  dimensions = {
    ApiId = aws_apigatewayv2_api.backoffice.id
  }

  tags = {
    Name            = "${var.environment}-backoffice-api-alarm"
    awsApplication  = aws_servicecatalogappregistry_application.backoffice.arn
  }
}
