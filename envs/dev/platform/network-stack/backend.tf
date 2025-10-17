# Dev Environment - Network Stack
# Backend configuration for Terraform state

terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"  # Thay bằng bucket từ foundation/backend
    key            = "dev/platform/network/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "terraform-state-lock"
  }
}
