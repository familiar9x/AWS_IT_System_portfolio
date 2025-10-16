variable "environment" {
  description = "Environment name"
  type        = string
}

variable "application_name" {
  description = "Name of the application"
  type        = string
}

variable "application_description" {
  description = "Description of the application"
  type        = string
}

variable "attribute_group_name" {
  description = "Name of the attribute group"
  type        = string
}

variable "attributes" {
  description = "Attributes for the application"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
