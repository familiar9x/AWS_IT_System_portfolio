# Dev Environment - WebPortal App Stack
# EC2, ALB, Auto Scaling cho web portal

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "dev/apps/webportal/app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "terraform-state-lock"
  }
}

# Register với AppRegistry
module "appregistry" {
  source = "../../../../modules/appregistry-application"

  application_name = "dev-webportal"
  description      = "Web Portal Application - Development"

  tags = {
    Environment  = "dev"
    Application  = "webportal"
    CostCenter   = "CC-001"
    BusinessUnit = "IT"
    Criticality  = "Medium"
  }
}

# Example: ALB
resource "aws_lb" "webportal" {
  name               = "dev-webportal-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  tags = merge(
    module.appregistry.application_tag,
    {
      Name        = "WebPortal Dev ALB"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  )
}

# Example: Security Group
resource "aws_security_group" "alb" {
  name_prefix = "dev-webportal-alb-"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    module.appregistry.application_tag,
    {
      Name        = "WebPortal Dev ALB SG"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  )
}

# Data sources
data "aws_vpc" "main" {
  tags = {
    Name = "dev-vpc"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Tier = "public"
  }
}
