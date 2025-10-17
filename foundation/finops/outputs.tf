output "cur_bucket_name" {
  description = "S3 bucket name for Cost & Usage Reports"
  value       = aws_s3_bucket.cur.id
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.main.arn
}

output "glue_database_name" {
  description = "Glue database name for CUR analysis"
  value       = aws_glue_catalog_database.cur.name
}

output "glue_crawler_name" {
  description = "Glue crawler name for CUR"
  value       = aws_glue_crawler.cur.name
}
