provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Layer     = "Foundation"
      Component = "TagReconciler"
    }
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "resource_explorer_view_arn" {
  description = "ARN of Resource Explorer view"
  type        = string
}
