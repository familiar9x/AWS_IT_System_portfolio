output "aggregator_arn" {
  description = "Config Aggregator ARN"
  value       = aws_config_configuration_aggregator.organization.arn
}

output "aggregator_name" {
  description = "Config Aggregator name"
  value       = aws_config_configuration_aggregator.organization.name
}

output "config_recorder_id" {
  description = "Config Recorder ID"
  value       = aws_config_configuration_recorder.main.id
}

output "config_bucket_name" {
  description = "S3 bucket name for Config"
  value       = aws_s3_bucket.config.id
}

output "config_bucket_arn" {
  description = "S3 bucket ARN for Config"
  value       = aws_s3_bucket.config.arn
}
