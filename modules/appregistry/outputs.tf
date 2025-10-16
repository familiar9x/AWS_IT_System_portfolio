output "application_id" {
  description = "Application ID"
  value       = aws_servicecatalogappregistry_application.main.id
}

output "application_arn" {
  description = "Application ARN"
  value       = aws_servicecatalogappregistry_application.main.arn
}

output "attribute_group_id" {
  description = "Attribute Group ID"
  value       = aws_servicecatalogappregistry_attribute_group.main.id
}

output "attribute_group_arn" {
  description = "Attribute Group ARN"
  value       = aws_servicecatalogappregistry_attribute_group.main.arn
}
