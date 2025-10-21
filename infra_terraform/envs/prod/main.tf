terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" { region = var.region }


variable "region" { type = string }
variable "name"   { type = string }
variable "tags"   { type = map(string) default = {} }


module "vpc" {
  source   = "../../modules/vpc"
  name     = var.name
  cidr     = "10.0.0.0/16"
  az_count = 3
  tags     = var.tags
}

module "ecr" {
  source = "../../modules/ecr"
  repos  = ["cmdb-api", "cmdb-extsys1", "cmdb-extsys2"]
  tags   = var.tags
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "${var.name}-eks"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "Allow EKS nodes to access RDS SQL Server"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "SQL Server"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  tags = var.tags
}

module "rds" {
  source                  = "../../modules/rds-mssql"
  db_name                 = "${var.name}-cmdb"
  username                = "cmdbadmin"
  password                = "ChangeMeStrong!123"
  subnet_ids              = module.vpc.private_subnet_ids
  vpc_security_group_ids  = [aws_security_group.rds.id]
}

output "rds_endpoint" { value = module.rds.endpoint }
