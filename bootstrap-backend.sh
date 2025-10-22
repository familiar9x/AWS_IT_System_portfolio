#!/bin/bash
# Bootstrap script to create Terraform backend infrastructure (S3 + DynamoDB)
# This script should be run ONCE before using remote state

set -e

# Configuration
ENVIRONMENT="prod"
REGION="ap-southeast-1"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
STATE_BUCKET_NAME="cmdb-terraform-state-${ACCOUNT_ID}-${REGION}"
LOCK_TABLE_NAME="cmdb-terraform-state-lock"

echo "🚀 Bootstrap Terraform Backend Infrastructure"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo "State Bucket: $STATE_BUCKET_NAME"
echo "Lock Table: $LOCK_TABLE_NAME"

# Check if bucket already exists
if aws s3api head-bucket --bucket "$STATE_BUCKET_NAME" 2>/dev/null; then
    echo "✅ S3 bucket $STATE_BUCKET_NAME already exists"
else
    echo "📦 Creating S3 bucket for Terraform state..."
    
    # Create the bucket
    aws s3api create-bucket \
        --bucket "$STATE_BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$STATE_BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$STATE_BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$STATE_BUCKET_NAME" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    echo "✅ S3 bucket created and configured"
fi

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "$LOCK_TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ DynamoDB table $LOCK_TABLE_NAME already exists"
else
    echo "🔒 Creating DynamoDB table for state locking..."
    
    aws dynamodb create-table \
        --table-name "$LOCK_TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --tags Key=Environment,Value="$ENVIRONMENT" Key=Purpose,Value="Terraform Backend"
    
    echo "⏳ Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$LOCK_TABLE_NAME" --region "$REGION"
    
    echo "✅ DynamoDB table created"
fi

# Create backend configuration file
cat > "backend.tf" << EOF
terraform {
  backend "s3" {
    bucket         = "$STATE_BUCKET_NAME"
    key            = "cmdb/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$LOCK_TABLE_NAME"
    encrypt        = true
  }
}
EOF

echo ""
echo "🎉 Terraform backend infrastructure created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Add backend configuration to your main.tf:"
echo "   terraform {"
echo "     backend \"s3\" {"
echo "       bucket         = \"$STATE_BUCKET_NAME\""
echo "       key            = \"cmdb/terraform.tfstate\""
echo "       region         = \"$REGION\""
echo "       dynamodb_table = \"$LOCK_TABLE_NAME\""
echo "       encrypt        = true"
echo "     }"
echo "   }"
echo ""
echo "2. Initialize Terraform with the new backend:"
echo "   terraform init"
echo ""
echo "3. If you have existing state, migrate it:"
echo "   terraform init -migrate-state"
echo ""
echo "Backend configuration saved to: backend.tf"
