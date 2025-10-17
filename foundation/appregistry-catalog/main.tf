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
