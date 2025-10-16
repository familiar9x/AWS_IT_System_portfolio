output "log_bucket_name" {
  description = "S3 bucket name for logs"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "log_bucket_arn" {
  description = "S3 bucket ARN for logs"
  value       = aws_s3_bucket.cloudtrail_logs.arn
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.organization.arn
}

output "cloudtrail_id" {
  description = "CloudTrail ID"
  value       = aws_cloudtrail.organization.id
}

output "kms_key_id" {
  description = "KMS key ID for CloudTrail encryption"
  value       = aws_kms_key.cloudtrail.id
}

output "kms_key_arn" {
  description = "KMS key ARN for CloudTrail encryption"
  value       = aws_kms_key.cloudtrail.arn
}
