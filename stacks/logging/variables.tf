variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "organization_id" {
  description = "AWS Organization ID"
  type        = string
}

variable "log_bucket_name" {
  description = "Name of the S3 bucket for logs"
  type        = string
}

variable "cloudtrail_name" {
  description = "Name of the CloudTrail"
  type        = string
}

variable "enable_s3_data_events" {
  description = "Enable S3 data events in CloudTrail"
  type        = bool
  default     = false
}

variable "enable_lambda_data_events" {
  description = "Enable Lambda data events in CloudTrail"
  type        = bool
  default     = false
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}
