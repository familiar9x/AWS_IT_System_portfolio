# Dev - WebPortal Application Stack
# ECS Fargate + ALB + Aurora MySQL + CloudWatch

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
    key            = "dev/apps-webportal/terraform.tfstate"
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
      System      = "webportal"
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources - Get platform outputs
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "dev/platform-network/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "dev/platform-iam-secrets/terraform.tfstate"
    region = var.region
  }
}

# AppRegistry Application
resource "aws_servicecatalogappregistry_application" "webportal" {
  name        = "${var.environment}-webportal"
  description = "WebPortal Application - ${upper(var.environment)} Environment"

  tags = {
    Name        = "${var.environment}-webportal"
    System      = "webportal"
    Environment = var.environment
    Owner       = var.owner
  }
}

# ECR Repository
resource "aws_ecr_repository" "webportal" {
  name                 = "${var.environment}/webportal"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name            = "${var.environment}-webportal-ecr"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "webportal" {
  repository = aws_ecr_repository.webportal.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name            = "${var.environment}-cluster"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "webportal" {
  name              = "/ecs/${var.environment}/webportal"
  retention_in_days = 7

  tags = {
    Name            = "${var.environment}-webportal-logs"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "webportal" {
  family                   = "${var.environment}-webportal"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"   # 0.25 vCPU
  memory                   = "512"   # 0.5 GB
  execution_role_arn       = data.terraform_remote_state.iam.outputs.ecs_task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.iam.outputs.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "webportal"
      image     = "${aws_ecr_repository.webportal.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "DB_HOST"
          value = aws_rds_cluster.webportal.endpoint
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = data.terraform_remote_state.iam.outputs.db_secrets_arns["webportal"]
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.webportal.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name            = "${var.environment}-webportal-task"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# Application Load Balancer
resource "aws_lb" "webportal" {
  name               = "${var.environment}-webportal-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.terraform_remote_state.network.outputs.alb_security_group_id]
  subnets            = data.terraform_remote_state.network.outputs.public_subnet_ids

  enable_deletion_protection = false
  enable_http2              = true

  tags = {
    Name            = "${var.environment}-webportal-alb"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# ALB Target Group
resource "aws_lb_target_group" "webportal" {
  name        = "${var.environment}-webportal-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name            = "${var.environment}-webportal-tg"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# ALB Listener
resource "aws_lb_listener" "webportal_http" {
  load_balancer_arn = aws_lb.webportal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webportal.arn
  }

  tags = {
    Name            = "${var.environment}-webportal-listener"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# ECS Service
resource "aws_ecs_service" "webportal" {
  name            = "${var.environment}-webportal"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webportal.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.terraform_remote_state.network.outputs.private_subnet_ids
    security_groups  = [data.terraform_remote_state.network.outputs.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.webportal.arn
    container_name   = "webportal"
    container_port   = 80
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight           = 1
    base             = 0
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 50
  }

  enable_execute_command = true

  tags = {
    Name            = "${var.environment}-webportal-service"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }

  depends_on = [aws_lb_listener.webportal_http]
}

# RDS Subnet Group
resource "aws_db_subnet_group" "webportal" {
  name       = "${var.environment}-webportal-subnet-group"
  subnet_ids = data.terraform_remote_state.network.outputs.database_subnet_ids

  tags = {
    Name            = "${var.environment}-webportal-subnet-group"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# Aurora MySQL Cluster (Serverless v2)
resource "aws_rds_cluster" "webportal" {
  cluster_identifier      = "${var.environment}-webportal-cluster"
  engine                  = "aurora-mysql"
  engine_mode             = "provisioned"
  engine_version          = "8.0.mysql_aurora.3.04.0"
  database_name           = "webportal"
  master_username         = "admin"
  master_password         = random_password.db_password.result
  db_subnet_group_name    = aws_db_subnet_group.webportal.name
  vpc_security_group_ids  = [data.terraform_remote_state.network.outputs.rds_security_group_id]

  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot     = true

  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]

  tags = {
    Name            = "${var.environment}-webportal-cluster"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

# Aurora Instance
resource "aws_rds_cluster_instance" "webportal" {
  identifier         = "${var.environment}-webportal-instance"
  cluster_identifier = aws_rds_cluster.webportal.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.webportal.engine
  engine_version     = aws_rds_cluster.webportal.engine_version

  tags = {
    Name            = "${var.environment}-webportal-instance"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Update Secrets Manager with DB endpoint
resource "aws_secretsmanager_secret_version" "db_credentials_update" {
  secret_id = data.terraform_remote_state.iam.outputs.db_secrets_arns["webportal"]
  
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
    engine   = "aurora-mysql"
    host     = aws_rds_cluster.webportal.endpoint
    port     = 3306
    dbname   = "webportal"
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.environment}-webportal-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS CPU utilization is too high"

  dimensions = {
    ServiceName = aws_ecs_service.webportal.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = {
    Name            = "${var.environment}-webportal-cpu-alarm"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.environment}-webportal-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "ALB 5xx errors are too high"

  dimensions = {
    LoadBalancer = aws_lb.webportal.arn_suffix
  }

  tags = {
    Name            = "${var.environment}-webportal-alb-alarm"
    awsApplication  = aws_servicecatalogappregistry_application.webportal.arn
  }
}
