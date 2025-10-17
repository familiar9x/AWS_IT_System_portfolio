# Global Variables
# Biến chung dùng cho toàn repo

variable "organization_name" {
  description = "Organization name"
  type        = string
  default     = "my-organization"
}

variable "default_region" {
  description = "Default AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "default_tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "IT-System-Portfolio"
  }
}

variable "environments" {
  description = "List of environments"
  type        = list(string)
  default     = ["dev", "stg", "prod"]
}
