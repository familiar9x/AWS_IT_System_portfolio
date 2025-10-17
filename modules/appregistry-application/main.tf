# Module: AppRegistry Application
# Tạo Application + auto-associate resources dựa trên tag

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Create Application in AppRegistry
resource "aws_servicecatalogappregistry_application" "app" {
  name        = var.application_name
  description = var.description

  tags = merge(
    var.tags,
    {
      awsApplication = var.application_name
      ManagedBy      = "Terraform"
    }
  )
}

# Associate with attribute groups
resource "aws_servicecatalogappregistry_attribute_group_association" "app" {
  for_each = toset(var.attribute_group_arns)

  application     = aws_servicecatalogappregistry_application.app.id
  attribute_group = each.value
}

# Associate resources (CloudFormation stacks, etc.)
resource "aws_servicecatalogappregistry_resource_association" "resources" {
  for_each = toset(var.resource_arns)

  application  = aws_servicecatalogappregistry_application.app.id
  resource     = each.value
  resource_type = var.resource_type
}

# Output để tag vào resources
output "application_tag" {
  description = "Tag to apply to resources for automatic association"
  value = {
    awsApplication = aws_servicecatalogappregistry_application.app.name
  }
}
