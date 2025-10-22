terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

# CloudFront needs ACM in us-east-1
provider "aws" {
  alias  = "use1"
  region = var.region_us_east_1
}

variable "account_id"       { type = string }
variable "region"           { type = string }           # e.g., ap-southeast-1
variable "region_us_east_1" { type = string }           # must be us-east-1 for CloudFront
variable "name"             { type = string }           # stack prefix, e.g., cmdb
variable "base_domain"      { type = string }           # example.com (must be a Route53 hosted zone)

# Certificates
variable "cloudfront_cert_arn" { type = string }        # ACM in us-east-1 for app.<base_domain>
variable "alb_cert_arn"        { type = string }        # ACM in primary region for api.<base_domain>

# DB
variable "db_username" { type = string }
variable "db_password" { type = string }

# Image tags
variable "api_image_tag"  { type = string }
variable "ext1_image_tag" { type = string }
variable "ext2_image_tag" { type = string }

variable "tags" { type = map(string) default = { Project = "CMDB" } }

# VPC
module "vpc" {
  source   = "../../modules/vpc"
  name     = var.name
  cidr     = "10.0.0.0/16"
  az_count = 2
  tags     = var.tags
}

# ALB
module "alb" {
  source            = "../../modules/alb"
  name              = var.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  cert_arn          = var.alb_cert_arn
  tags              = var.tags
}

# ECS
module "ecs" {
  source = "../../modules/ecs"
  name   = var.name
}

# ECR
module "ecr" {
  source = "../../modules/ecr"
  repos  = ["cmdb-api", "cmdb-extsys1", "cmdb-extsys2"]
}

# Secrets
module "secrets" {
  source      = "../../modules/secrets"
  name        = var.name
  db_password = var.db_password
}

# RDS
resource "aws_security_group" "svc_placeholder" { name="${var.name}-svc-ph", vpc_id=module.vpc.vpc_id }
module "rds" {
  source       = "../../modules/rds-mssql"
  name         = "${var.name}-cmdb"
  username     = var.db_username
  password     = var.db_password
  subnet_ids   = module.vpc.private_subnet_ids
  vpc_id       = module.vpc.vpc_id
  source_sg_id = aws_security_group.svc_placeholder.id
}

# Services
module "services" {
  source             = "../../modules/services"
  name               = var.name
  cluster_arn        = module.ecs.cluster_arn
  cluster_name       = module.ecs.cluster_name
  task_exec_role_arn = module.ecs.task_exec_role_arn
  task_role_arn      = module.ecs.task_role_arn
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  tg_api_arn         = module.alb.tg_api_arn
  rds_endpoint       = module.rds.endpoint
  db_user            = var.db_username
  db_name            = "CMDB"
  db_pass_secret_arn = module.secrets.db_secret_arn
  region             = var.region

  repo_api  = module.ecr.repo_urls["cmdb-api"]
  repo_ext1 = module.ecr.repo_urls["cmdb-extsys1"]
  repo_ext2 = module.ecr.repo_urls["cmdb-extsys2"]

  api_tag  = var.api_image_tag
  ext1_tag = var.ext1_image_tag
  ext2_tag = var.ext2_image_tag
}

# Allow RDS from services SG
resource "aws_security_group_rule" "rds_allow" {
  type                     = "ingress"
  security_group_id        = module.rds.sg_id
  from_port                = 1433
  to_port                  = 1433
  protocol                 = "tcp"
  source_security_group_id = module.services.svc_sg_id
}

# Monitoring and Alerting
module "monitoring" {
  source                   = "../../modules/monitoring"
  name                     = var.name
  cluster_name             = module.ecs.cluster_name
  service_names            = ["api", "extsys1", "extsys2"]
  alb_arn_suffix          = split("/", module.alb.alb_arn)[1]
  target_group_arn_suffix = split("/", module.alb.tg_api_arn)[1]
  # sns_topic_arn          = aws_sns_topic.alerts.arn  # Uncomment when SNS is set up
}

# AI Assistant
module "ai_assistant" {
  source             = "../../modules/ai-assistant"
  name               = var.name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.rds.sg_id
  db_secret_arn      = module.secrets.db_secret_arn
  tags               = var.tags
}

# CloudFront + S3 for FE
module "cf_fe" {
  source            = "../../modules/cf-s3-oac"
  providers         = { aws.use1 = aws.use1 } # ACM in us-east-1
  name              = var.name
  domain_name       = "app.${var.base_domain}"
  hosted_zone_name  = var.base_domain
  cert_arn_use1     = var.cloudfront_cert_arn
}

# Route53 for API (ALB)
data "aws_lb" "alb" { arn = module.alb.alb_arn }
module "route53_api" {
  source           = "../../modules/route53-api"
  record_name      = "api.${var.base_domain}"
  hosted_zone_name = var.base_domain
  alb_dns          = module.alb.alb_dns
  alb_zone_id      = data.aws_lb.alb.zone_id
}

# Outputs
output "fe_bucket"           { value = module.cf_fe.bucket_name }
output "fe_distribution_id"  { value = module.cf_fe.distribution_id }
output "fe_distribution_host"{ value = module.cf_fe.distribution_host }
output "alb_dns"             { value = module.alb.alb_dns }
output "rds_endpoint"        { value = module.rds.endpoint }

# Monitoring outputs
output "cloudwatch_dashboard_url" { 
  value = module.monitoring.dashboard_url 
  description = "URL to the CloudWatch dashboard"
}

output "api_endpoints" {
  value = {
    health = "https://api.${var.base_domain}/health"
    api_v1 = "https://api.${var.base_domain}/api/v1"
    ai_ask = module.ai_assistant.ask_endpoint
  }
  description = "API endpoints for testing"
}

# AI Assistant outputs
output "ai_assistant_api_url" {
  value = module.ai_assistant.api_gateway_url
  description = "AI Assistant API Gateway URL"
}

output "ai_ask_endpoint" {
  value = module.ai_assistant.ask_endpoint
  description = "AI Ask endpoint for frontend integration"
}

output "ai_ecr_repository" {
  value = module.ai_assistant.ecr_repository_url
  description = "ECR repository URL for AI Lambda"
}
