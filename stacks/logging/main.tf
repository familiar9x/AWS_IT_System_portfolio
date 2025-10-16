# Logging Organization Trail Module
module "logging_org_trail" {
  source = "../../modules/logging_org_trail"

  environment                = var.environment
  organization_id            = var.organization_id
  log_bucket_name           = var.log_bucket_name
  cloudtrail_name           = var.cloudtrail_name
  enable_s3_data_events     = var.enable_s3_data_events
  enable_lambda_data_events = var.enable_lambda_data_events
  
  tags = var.default_tags
}
