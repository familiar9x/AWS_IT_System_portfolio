variable "application_name" {
  description = "Name of the AppRegistry application"
  type        = string
}

variable "description" {
  description = "Description of the application"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for the application"
  type        = map(string)
  default     = {}
}

variable "attribute_group_arns" {
  description = "List of attribute group ARNs to associate with"
  type        = list(string)
  default     = []
}

variable "resource_arns" {
  description = "List of resource ARNs to associate with application"
  type        = list(string)
  default     = []
}

variable "resource_type" {
  description = "Type of resources to associate (CFN_STACK, RESOURCE_TAG_VALUE)"
  type        = string
  default     = "CFN_STACK"
}
