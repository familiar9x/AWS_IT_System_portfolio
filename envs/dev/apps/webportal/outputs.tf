output "appregistry_application_arn" {
  description = "ARN of AppRegistry Application"
  value       = aws_servicecatalogappregistry_application.webportal.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.webportal.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.webportal.name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.webportal.dns_name
}

output "alb_url" {
  description = "ALB URL"
  value       = "http://${aws_lb.webportal.dns_name}"
}

output "rds_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.webportal.endpoint
  sensitive   = true
}

output "rds_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.webportal.reader_endpoint
  sensitive   = true
}
