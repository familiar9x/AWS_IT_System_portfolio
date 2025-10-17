variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "owner" {
  description = "Team or person responsible"
  type        = string
  default     = "team-app@company.com"
}
