variable "environment" {
  description = "Environment name"
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
