output "config_rule_dev_tags_arn" {
  description = "ARN of dev required tags config rule"
  value       = aws_config_config_rule.dev_required_tags.arn
}

output "config_rule_s3_versioning_arn" {
  description = "ARN of S3 versioning config rule"
  value       = aws_config_config_rule.dev_s3_versioning.arn
}
