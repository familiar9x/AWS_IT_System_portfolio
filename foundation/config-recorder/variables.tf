variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "config_bucket_name" {
  description = "S3 bucket name for AWS Config logs"
  type        = string
}

variable "enable_all_regions" {
  description = "Enable Config in all regions"
  type        = bool
  default     = false
}
