# Prod Environment - Backend Configuration

bucket         = "my-terraform-state-123456789012"
key            = "prod/STACK_NAME/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
kms_key_id     = "alias/terraform-state"

# Replace STACK_NAME with actual stack name:
# - platform-network
# - platform-iam
# - apps-webportal
# - apps-backoffice
# - config-recorder
# - observability
