# Dev - Observability Stack
# CloudWatch Dashboards, Alarms, X-Ray

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
    key            = "dev/observability/terraform.tfstate"
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
      ManagedBy   = "Terraform"
      Component   = "Observability"
    }
  }
}

# CloudWatch Dashboard - Platform Overview
resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = "dev-platform-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }],
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "CPU Utilization - Dev Environment"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            [".", "RequestCount", { stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ALB Metrics - Dev Environment"
        }
      }
    ]
  })
}

# CloudWatch Dashboard - Application Metrics
resource "aws_cloudwatch_dashboard" "applications" {
  dashboard_name = "dev-applications"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average", label = "WebPortal CPU" }],
            [".", "MemoryUtilization", { stat = "Average", label = "WebPortal Memory" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "WebPortal Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum" }],
            [".", "Errors", { stat = "Sum" }],
            [".", "Duration", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Lambda Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { stat = "Average" }],
            [".", "ReadLatency", { stat = "Average" }],
            [".", "WriteLatency", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Database Metrics"
        }
      }
    ]
  })
}

# CloudWatch Alarm - High CPU (ECS)
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "dev-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = "webportal-dev"
    ClusterName = "dev-cluster"
  }
}

# CloudWatch Alarm - ALB 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "dev-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 5xx errors"
  treat_missing_data  = "notBreaching"
}

# CloudWatch Alarm - RDS High CPU
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "dev-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  treat_missing_data  = "notBreaching"
}

# CloudWatch Alarm - Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "dev-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors Lambda errors"
  treat_missing_data  = "notBreaching"
}

# X-Ray Sampling Rule for dev
resource "aws_xray_sampling_rule" "dev" {
  rule_name      = "dev-sampling"
  priority       = 100
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.05  # 5% sampling for dev
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  attributes = {
    Environment = "dev"
  }
}

# CloudWatch Log Groups - Centralized
resource "aws_cloudwatch_log_group" "applications" {
  for_each = toset(["webportal", "api-service"])

  name              = "/aws/application/dev/${each.key}"
  retention_in_days = 7  # Short retention for dev

  tags = {
    Name        = "dev-${each.key}-logs"
    Application = each.key
  }
}

# CloudWatch Contributor Insights Rule - Top API Endpoints
resource "aws_cloudwatch_log_group" "contributor_insights" {
  name              = "/aws/application/dev/contributor-insights"
  retention_in_days = 7
}
