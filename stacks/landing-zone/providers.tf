terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    key = "landing-zone/terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = var.default_tags
  }
}
