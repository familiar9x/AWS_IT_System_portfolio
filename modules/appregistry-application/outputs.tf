output "application_id" {
  description = "ID of the AppRegistry application"
  value       = aws_servicecatalogappregistry_application.app.id
}

output "application_arn" {
  description = "ARN of the AppRegistry application"
  value       = aws_servicecatalogappregistry_application.app.arn
}

output "application_name" {
  description = "Name of the AppRegistry application"
  value       = aws_servicecatalogappregistry_application.app.name
}

output "application_tag" {
  description = "Tag to apply to resources for automatic association"
  value = {
    awsApplication = aws_servicecatalogappregistry_application.app.name
  }
}
