# Backend configuration for dev environment
bucket         = "terraform-state-dev-yourcompany"
key            = "will-be-overridden-by-stack"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "arn:aws:kms:us-east-1:111111111111:key/your-kms-key-id"
dynamodb_table = "terraform-state-lock-dev"
