variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, stg, prod)"
  type        = string
}

variable "organization_id" {
  description = "AWS Organization ID"
  type        = string
}

variable "aggregator_name" {
  description = "Name of the Config Aggregator"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}
