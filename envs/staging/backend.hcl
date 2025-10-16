# Backend configuration for staging environment
bucket         = "terraform-state-staging-yourcompany"
key            = "will-be-overridden-by-stack"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "arn:aws:kms:us-east-1:222222222222:key/your-kms-key-id"
dynamodb_table = "terraform-state-lock-staging"
