# Config Aggregator Module
module "config_aggregator" {
  source = "../../modules/config_aggregator"

  environment     = var.environment
  organization_id = var.organization_id
  aggregator_name = var.aggregator_name
  
  tags = var.default_tags
}
