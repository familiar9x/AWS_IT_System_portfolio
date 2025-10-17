output "index_arn" {
  description = "Resource Explorer Index ARN"
  value       = aws_resourceexplorer2_index.aggregator.arn
}

output "default_view_arn" {
  description = "Default View ARN"
  value       = aws_resourceexplorer2_view.default.arn
}

output "applications_view_arn" {
  description = "Applications View ARN"
  value       = aws_resourceexplorer2_view.applications.arn
}
