terraform {
  backend "s3" {
    bucket         = "my-terraform-state-123456789012"
    key            = "dev/platform-iam-secrets/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
  }
}
