variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
  default     = ""
}
