output "state_bucket_name" {
  description = "Name of S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "kms_key_id" {
  description = "ID of KMS key for state encryption"
  value       = aws_kms_key.terraform_state.id
}

output "kms_key_arn" {
  description = "ARN of KMS key for state encryption"
  value       = aws_kms_key.terraform_state.arn
}
