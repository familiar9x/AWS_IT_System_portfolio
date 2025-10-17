output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "db_secrets_arns" {
  description = "ARNs of database credential secrets"
  value = {
    for k, v in aws_secretsmanager_secret.db_credentials :
    k => v.arn
  }
}

output "app_config_parameter_names" {
  description = "Names of application config SSM parameters"
  value = {
    for k, v in aws_ssm_parameter.app_config :
    k => v.name
  }
}
