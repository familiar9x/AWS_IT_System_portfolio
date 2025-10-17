variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "organization_name" {
  description = "Organization name"
  type        = string
}

variable "organizational_units" {
  description = "Map of organizational units to create"
  type = map(object({
    name   = string
    parent = string
  }))
  default = {}
}

variable "scp_policies" {
  description = "Service Control Policies"
  type = map(object({
    name        = string
    description = string
    policy      = string
    targets     = list(string)
  }))
  default = {}
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}
