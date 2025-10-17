output "aggregator_arn" {
  description = "Config Aggregator ARN"
  value       = module.config_aggregator.aggregator_arn
}

output "aggregator_name" {
  description = "Config Aggregator name"
  value       = module.config_aggregator.aggregator_name
}
