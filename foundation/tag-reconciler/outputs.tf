output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.tag_reconciler.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.tag_reconciler.function_name
}

output "eventbridge_rule_arn" {
  description = "EventBridge rule ARN"
  value       = aws_cloudwatch_event_rule.tag_reconciler_schedule.arn
}
