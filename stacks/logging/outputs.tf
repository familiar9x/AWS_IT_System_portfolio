output "log_bucket_name" {
  description = "S3 bucket name for logs"
  value       = module.logging_org_trail.log_bucket_name
}

output "log_bucket_arn" {
  description = "S3 bucket ARN for logs"
  value       = module.logging_org_trail.log_bucket_arn
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = module.logging_org_trail.cloudtrail_arn
}

output "cloudtrail_id" {
  description = "CloudTrail ID"
  value       = module.logging_org_trail.cloudtrail_id
}
