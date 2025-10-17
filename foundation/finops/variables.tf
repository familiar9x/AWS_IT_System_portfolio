variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cur_bucket_name" {
  description = "S3 bucket name for Cost & Usage Reports"
  type        = string
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "enable_cur" {
  description = "Enable Cost & Usage Report"
  type        = bool
  default     = true
}
