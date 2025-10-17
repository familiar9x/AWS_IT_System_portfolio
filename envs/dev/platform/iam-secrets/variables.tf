variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "applications" {
  description = "Map of applications and their configurations"
  type = map(object({
    db_engine = string
    db_port   = number
    db_name   = string
  }))
  default = {
    webportal = {
      db_engine = "postgres"
      db_port   = 5432
      db_name   = "webportal"
    }
    api-service = {
      db_engine = "mysql"
      db_port   = 3306
      db_name   = "apiservice"
    }
  }
}

variable "default_tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Layer       = "Platform"
    Component   = "IAM-Secrets"
  }
}
