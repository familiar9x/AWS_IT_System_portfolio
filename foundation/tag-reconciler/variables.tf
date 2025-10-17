variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "resource_explorer_view_arn" {
  description = "ARN of Resource Explorer View to use for querying resources"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule expression for tag reconciler"
  type        = string
  default     = "rate(6 hours)"
}
