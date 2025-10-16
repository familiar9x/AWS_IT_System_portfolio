# Backend configuration for prod environment
bucket         = "terraform-state-prod-yourcompany"
key            = "will-be-overridden-by-stack"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "arn:aws:kms:us-east-1:333333333333:key/your-kms-key-id"
dynamodb_table = "terraform-state-lock-prod"
