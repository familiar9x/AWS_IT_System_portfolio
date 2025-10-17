output "platform_dashboard_name" {
  description = "Name of platform CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.platform.dashboard_name
}

output "applications_dashboard_name" {
  description = "Name of applications CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.applications.dashboard_name
}

output "alarm_arns" {
  description = "ARNs of CloudWatch alarms"
  value = {
    ecs_high_cpu  = aws_cloudwatch_metric_alarm.ecs_high_cpu.arn
    alb_5xx       = aws_cloudwatch_metric_alarm.alb_5xx_errors.arn
    rds_high_cpu  = aws_cloudwatch_metric_alarm.rds_high_cpu.arn
    lambda_errors = aws_cloudwatch_metric_alarm.lambda_errors.arn
  }
}

output "xray_sampling_rule_name" {
  description = "Name of X-Ray sampling rule"
  value       = aws_xray_sampling_rule.dev.rule_name
}
