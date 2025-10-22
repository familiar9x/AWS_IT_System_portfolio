variable "name" { type = string }
variable "cluster_arn" { type = string }
variable "cluster_name" { type = string }
variable "task_exec_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }
variable "tg_api_arn" { type = string }
variable "rds_endpoint" { type = string }
variable "db_user" { type = string }
variable "db_name" { type = string }
variable "db_pass_secret_arn" { type = string }
variable "region" { type = string }

variable "repo_api" { type = string }
variable "repo_ext1" { type = string }
variable "repo_ext2" { type = string }

variable "api_tag"  { type = string }
variable "ext1_tag" { type = string }
variable "ext2_tag" { type = string }

resource "aws_security_group" "svc" {
  name   = "${var.name}-svc-sg"
  vpc_id = var.vpc_id
  ingress { from_port=3000 to_port=3000 protocol="tcp" security_groups=[var.alb_sg_id] }
  egress  { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
}

locals {
  log_api  = { "awslogs-group"="/ecs/${var.name}-api", "awslogs-region"=var.region, "awslogs-stream-prefix"="ecs" }
  log_ext1 = { "awslogs-group"="/ecs/${var.name}-extsys1", "awslogs-region"=var.region, "awslogs-stream-prefix"="ecs" }
  log_ext2 = { "awslogs-group"="/ecs/${var.name}-extsys2", "awslogs-region"=var.region, "awslogs-stream-prefix"="ecs" }
}

resource "aws_cloudwatch_log_group" "api"  { name="/ecs/${var.name}-api" retention_in_days=30 }
resource "aws_cloudwatch_log_group" "ext1" { name="/ecs/${var.name}-extsys1" retention_in_days=30 }
resource "aws_cloudwatch_log_group" "ext2" { name="/ecs/${var.name}-extsys2" retention_in_days=30 }

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.task_exec_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name="api", image="${var.repo_api}:${var.api_tag}", essential=true,
    portMappings=[{containerPort=3000, protocol="tcp"}],
    environment=[
      {name="DB_HOST", value=var.rds_endpoint},
      {name="DB_USER", value=var.db_user},
      {name="DB_NAME", value=var.db_name},
      {name="EXTSYS1_URL", value="http://extsys1:8001/devices"},
      {name="EXTSYS2_URL", value="http://extsys2:8002/devices"}
    ],
    secrets=[{name="DB_PASS", valueFrom=var.db_pass_secret_arn}],
    logConfiguration={logDriver="awslogs", options=local.log_api},
    healthCheck={command=["CMD-SHELL","curl -f http://localhost:3000/health || exit 1"], interval=15, timeout=5, retries=3, startPeriod=10}
  }])
}

resource "aws_ecs_task_definition" "ext1" {
  family = "${var.name}-extsys1"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "256"
  memory = "512"
  execution_role_arn = var.task_exec_role_arn
  task_role_arn      = var.task_role_arn
  container_definitions = jsonencode([{
    name="extsys1", image="${var.repo_ext1}:${var.ext1_tag}", essential=true,
    portMappings=[{containerPort=8001, protocol="tcp"}],
    logConfiguration={logDriver="awslogs", options=local.log_ext1}
  }])
}

resource "aws_ecs_task_definition" "ext2" {
  family = "${var.name}-extsys2"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "256"
  memory = "512"
  execution_role_arn = var.task_exec_role_arn
  task_role_arn      = var.task_role_arn
  container_definitions = jsonencode([{
    name="extsys2", image="${var.repo_ext2}:${var.ext2_tag}", essential=true,
    portMappings=[{containerPort=8002, protocol="tcp"}],
    logConfiguration={logDriver="awslogs", options=local.log_ext2}
  }])
}

resource "aws_ecs_service" "api" {
  name            = "${var.name}-api"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = var.tg_api_arn
    container_name   = "api"
    container_port   = 3000
  }
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}

resource "aws_ecs_service" "ext1" {
  name            = "${var.name}-extsys1"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.ext1.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }
}

resource "aws_ecs_service" "ext2" {
  name            = "${var.name}-extsys2"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.ext2.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }
}

# EventBridge scheduled task (hourly) to run ingest
data "aws_caller_identity" "me" {}

resource "aws_iam_role" "events" {
  name = "${var.name}-events-role"
  assume_role_policy = jsonencode({
    Version="2012-10-17", Statement=[{Effect="Allow", Action="sts:AssumeRole", Principal={Service="events.amazonaws.com"}}]
  })
}

resource "aws_iam_role_policy" "events_run_task" {
  name = "${var.name}-events-policy"
  role = aws_iam_role.events.id
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[
      {Effect="Allow", Action=["ecs:RunTask"], Resource="*"},
      {Effect="Allow", Action=["iam:PassRole"], Resource=[var.task_exec_role_arn, var.task_role_arn]}
    ]
  })
}

resource "aws_cloudwatch_event_rule" "ingest" {
  name                = "${var.name}-ingest-hourly"
  schedule_expression = "cron(0 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "ingest" {
  rule      = aws_cloudwatch_event_rule.ingest.name
  target_id = "run-task"
  arn       = "arn:aws:ecs:${var.region}:${data.aws_caller_identity.me.account_id}:cluster/${var.cluster_name}"
  role_arn  = aws_iam_role.events.arn
  ecs_target {
    launch_type = "FARGATE"
    task_count  = 1
    task_definition_arn = aws_ecs_task_definition.api.arn
    network_configuration {
      subnets         = var.private_subnet_ids
      security_groups = [aws_security_group.svc.id]
      assign_public_ip = false
    }
  }
}

output "svc_sg_id" { value = aws_security_group.svc.id }
