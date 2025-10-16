# AWS Service Catalog AppRegistry Application
resource "aws_servicecatalogappregistry_application" "main" {
  name        = var.application_name
  description = var.application_description

  tags = var.tags
}

# AWS Service Catalog AppRegistry Attribute Group
resource "aws_servicecatalogappregistry_attribute_group" "main" {
  name        = var.attribute_group_name
  description = "Attribute group for ${var.application_name}"

  attributes = jsonencode(var.attributes)

  tags = var.tags
}

# Associate Attribute Group with Application
resource "aws_servicecatalogappregistry_attribute_group_association" "main" {
  application           = aws_servicecatalogappregistry_application.main.id
  attribute_group       = aws_servicecatalogappregistry_attribute_group.main.id
}

# Resource Tag Association (example for tagging resources)
# This would be used to associate resources with the application
# based on the awsApplication tag
