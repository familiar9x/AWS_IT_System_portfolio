variable "environment" {
  description = "Environment name (e.g., prod, dev, staging)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-lock"
}
