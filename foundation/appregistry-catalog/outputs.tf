output "portfolio_id" {
  description = "AppRegistry Application Portfolio ID"
  value       = aws_servicecatalogappregistry_application.system_catalog.id
}

output "portfolio_arn" {
  description = "AppRegistry Application Portfolio ARN"
  value       = aws_servicecatalogappregistry_application.system_catalog.arn
}

output "attribute_group_id" {
  description = "Classification Attribute Group ID"
  value       = aws_servicecatalogappregistry_attribute_group.classification.id
}

output "attribute_group_arn" {
  description = "Classification Attribute Group ARN"
  value       = aws_servicecatalogappregistry_attribute_group.classification.arn
}

output "system_applications" {
  description = "Map of created AppRegistry Applications by system-environment"
  value = {
    for key, app in aws_servicecatalogappregistry_application.system_apps :
    key => {
      id   = app.id
      arn  = app.arn
      name = app.name
    }
  }
}
