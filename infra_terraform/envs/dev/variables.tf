# Development Environment Variables
variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "region_us_east_1" {
  description = "US East 1 region for CloudFront"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Project name prefix"
  type        = string
  default     = "cmdb-dev"
}

variable "base_domain" {
  description = "Base domain name"
  type        = string
}

variable "cloudfront_cert_arn" {
  description = "ACM certificate ARN in us-east-1"
  type        = string
}

variable "alb_cert_arn" {
  description = "ACM certificate ARN in primary region"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "cmdbadmin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "api_image_tag" {
  description = "Docker image tag for API"
  type        = string
  default     = "latest"
}

variable "ext1_image_tag" {
  description = "Docker image tag for external system 1"
  type        = string
  default     = "latest"
}

variable "ext2_image_tag" {
  description = "Docker image tag for external system 2"
  type        = string
  default     = "latest"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "CMDB"
    Owner       = "dev-team"
    CostCenter  = "engineering"
  }
}
