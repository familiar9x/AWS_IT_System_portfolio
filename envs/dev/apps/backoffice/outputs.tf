output "appregistry_application_arn" {
  description = "ARN of AppRegistry Application"
  value       = aws_servicecatalogappregistry_application.backoffice.arn
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.backoffice.id
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.api_handler.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.api_handler.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.backoffice.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.backoffice.arn
}

output "s3_bucket_name" {
  description = "S3 bucket for Lambda artifacts"
  value       = aws_s3_bucket.lambda_artifacts.id
}
