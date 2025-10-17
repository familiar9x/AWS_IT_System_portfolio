output "config_recorder_name" {
  description = "Name of the Config Recorder"
  value       = aws_config_configuration_recorder.main.name
}

output "config_bucket_name" {
  description = "S3 bucket name for Config logs"
  value       = aws_s3_bucket.config.id
}

output "config_bucket_arn" {
  description = "S3 bucket ARN for Config logs"
  value       = aws_s3_bucket.config.arn
}

output "config_role_arn" {
  description = "IAM Role ARN for Config"
  value       = aws_iam_role.config.arn
}
