# Foundation: AWS Service Catalog AppRegistry
# Tạo System Catalog trung tâm cho toàn org

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AppRegistry Application Portfolio
resource "aws_servicecatalogappregistry_application" "system_catalog" {
  name        = "it-system-portfolio"
  description = "IT System Portfolio - CMDB trung tâm"

  tags = {
    Name        = "IT System Portfolio"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }
}

# Attribute Groups for classification
resource "aws_servicecatalogappregistry_attribute_group" "classification" {
  name        = "system-classification"
  description = "Classification attributes for IT systems"

  attributes = jsonencode({
    businessUnit = ["Finance", "HR", "IT", "Sales", "Operations"]
    costCenter   = ["CC-001", "CC-002", "CC-003"]
    criticality  = ["Critical", "High", "Medium", "Low"]
    dataClass    = ["Confidential", "Internal", "Public"]
  })

  tags = {
    Name        = "System Classification"
    Environment = "foundation"
    ManagedBy   = "Terraform"
  }
}

# Associate attribute group with application
resource "aws_servicecatalogappregistry_attribute_group_association" "classification" {
  application = aws_servicecatalogappregistry_application.system_catalog.id
  attribute_group = aws_servicecatalogappregistry_attribute_group.classification.id
}

# Create AppRegistry Applications for each system-environment
locals {
  # Flatten systems and environments into a map with format: {environment}-{system}
  system_envs = merge([
    for system in var.systems : {
      for env in system.environments :
      "${env}-${system.name}" => {  # Changed to: environment-system
        system_name = system.name
        environment = env
        description = system.description
      }
    }
  ]...)
}

resource "aws_servicecatalogappregistry_application" "system_apps" {
  for_each = local.system_envs

  name        = each.key  # e.g., "dev-webportal"
  description = "${each.value.description} - ${upper(each.value.environment)} Environment"

  tags = {
    Name        = each.key
    System      = each.value.system_name
    Environment = each.value.environment
    ManagedBy   = "Terraform"
  }
}

# Associate each system app with the classification attribute group
resource "aws_servicecatalogappregistry_attribute_group_association" "system_apps" {
  for_each = aws_servicecatalogappregistry_application.system_apps

  application     = each.value.id
  attribute_group = aws_servicecatalogappregistry_attribute_group.classification.id
}
