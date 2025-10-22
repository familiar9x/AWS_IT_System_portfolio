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
variable "region"           { type = string }
variable "region_us_east_1" { type = string }
variable "name"             { type = string }
variable "base_domain"      { type = string }

# Certificates
variable "cloudfront_cert_arn" { type = string }
variable "alb_cert_arn"        { type = string }

# DB
variable "db_username" { type = string }
variable "db_password" { type = string }

# Image tags
variable "api_image_tag"  { type = string }
variable "ext1_image_tag" { type = string }
variable "ext2_image_tag" { type = string }

variable "tags" { 
  type = map(string) 
  default = { 
    Project = "CMDB"
    Environment = "development"
  } 
}

# Development-specific locals
locals {
  is_dev = contains(["dev", "development"], lower(var.tags.Environment))
  
  # Smaller instances for development
  db_instance_class = local.is_dev ? "db.t3.micro" : "db.m6i.large"
  db_allocated_storage = local.is_dev ? 20 : 50
  
  # Reduced capacity for development
  api_cpu    = local.is_dev ? "256" : "512"
  api_memory = local.is_dev ? "512" : "1024"
  
  ext_cpu    = local.is_dev ? "256" : "256"
  ext_memory = local.is_dev ? "512" : "512"
}

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

# RDS with environment-specific configuration
resource "aws_security_group" "svc_placeholder" { 
  name   = "${var.name}-svc-ph"
  vpc_id = module.vpc.vpc_id 
}

module "rds" {
  source       = "../../modules/rds-mssql"
  name         = "${var.name}-cmdb"
  username     = var.db_username
  password     = var.db_password
  subnet_ids   = module.vpc.private_subnet_ids
  vpc_id       = module.vpc.vpc_id
  source_sg_id = aws_security_group.svc_placeholder.id
}

# Services with environment-specific resources
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
}

# CloudFront + S3 for FE
module "cf_fe" {
  source            = "../../modules/cf-s3-oac"
  providers         = { aws.use1 = aws.use1 }
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
output "environment" { 
  value = var.tags.Environment 
  description = "Current environment"
}

output "fe_bucket" { 
  value = module.cf_fe.bucket_name 
}

output "fe_distribution_id" { 
  value = module.cf_fe.distribution_id 
}

output "fe_distribution_host" { 
  value = module.cf_fe.distribution_host 
}

output "alb_dns" { 
  value = module.alb.alb_dns 
}

output "rds_endpoint" { 
  value = module.rds.endpoint 
}

output "cloudwatch_dashboard_url" { 
  value = module.monitoring.dashboard_url 
}

output "api_endpoints" {
  value = {
    health = "https://api.${var.base_domain}/health"
    api_v1 = "https://api.${var.base_domain}/api/v1"
  }
}

output "resource_summary" {
  value = {
    environment     = var.tags.Environment
    db_instance     = local.db_instance_class
    api_resources   = "${local.api_cpu} CPU / ${local.api_memory} MB"
    estimated_cost  = local.is_dev ? "~$30-50/month" : "~$150-300/month"
  }
}
