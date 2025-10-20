variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "portfolio_name" {
  description = "Name of the AppRegistry Application Portfolio"
  type        = string
  default     = "it-system-portfolio"
}

variable "systems" {
  description = "List of systems to create AppRegistry Applications for"
  type = list(object({
    name        = string
    description = string
    environments = list(string)
  }))
  default = [
    {
      name        = "webportal"
      description = "Web Portal Application"
      environments = ["dev", "stg", "prod"]
    },
    {
      name        = "backoffice"
      description = "Backoffice API Application"
      environments = ["dev", "stg", "prod"]
    }
  ]
}
