# Config Recorder for Dev Environment
# AWS Config local - bắt buộc để aggregator gom

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
    key            = "dev/config-recorder/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "terraform-state-lock"
  }
}

module "config_recorder" {
  source = "../../../modules/config-recorder"

  environment = "dev"
}
