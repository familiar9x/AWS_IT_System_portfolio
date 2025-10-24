#!/bin/bash
# Deploy script for DEV environment
# This script deploys the CMDB infrastructure to DEV environment

set -e

echo "🚀 Deploying CMDB to DEV Environment"
echo "======================================"
echo ""

# Change to dev directory
cd "$(dirname "$0")/infra_terraform/envs/dev"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ Error: terraform.tfvars not found${NC}"
    echo ""
    echo "Please create terraform.tfvars from the example:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo ""
    echo "Then edit it with your actual values:"
    echo "  - account_id: Your AWS Account ID"
    echo "  - region: Your preferred AWS region (e.g., us-east-1)"
    echo "  - base_domain: Your domain name (e.g., example.com)"
    echo "  - db_password: Strong database password"
    echo "  - dev_users: List of developer usernames"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Found terraform.tfvars${NC}"
echo ""

# Step 2: Check AWS credentials
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: AWS credentials not configured${NC}"
    echo ""
    echo "Please configure AWS CLI:"
    echo "  aws configure"
    echo ""
    echo "Or set environment variables:"
    echo "  export AWS_ACCESS_KEY_ID=your_key"
    echo "  export AWS_SECRET_ACCESS_KEY=your_secret"
    echo "  export AWS_DEFAULT_REGION=us-east-1"
    echo ""
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
echo -e "${GREEN}✅ AWS Account ID: $ACCOUNT_ID${NC}"
echo -e "${GREEN}✅ Current User: $CURRENT_USER${NC}"
echo ""

# Step 3: Check if backend is configured
if [ ! -f "backend.tf" ]; then
    echo -e "${YELLOW}⚠️  Backend not configured yet${NC}"
    echo ""
    echo "You need to create backend infrastructure first:"
    echo "  1. Run: cd ../../.. && ./bootstrap-backend.sh dev"
    echo "  2. Then come back and run this script again"
    echo ""
    read -p "Do you want to continue with local state? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 4: Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Step 5: Validate configuration
echo ""
echo "🔍 Validating Terraform configuration..."
terraform validate

# Step 6: Plan
echo ""
echo "📋 Creating Terraform plan..."
terraform plan -out=tfplan

# Step 7: Confirm before apply
echo ""
echo -e "${YELLOW}⚠️  Ready to deploy to DEV environment${NC}"
echo ""
echo "This will create:"
echo "  - VPC with public/private subnets"
echo "  - ECS Cluster"
echo "  - RDS SQL Server database"
echo "  - Application Load Balancer"
echo "  - CloudFront distribution"
echo "  - S3 bucket for frontend"
echo "  - ECR repositories"
echo "  - IAM deployment users"
echo "  - EventBridge automated ingest"
echo "  - AI Assistant (Lambda + API Gateway)"
echo ""
read -p "Do you want to proceed? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Step 8: Apply
echo ""
echo "🚀 Applying Terraform configuration..."
terraform apply tfplan

# Step 9: Show outputs
echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo "📊 Infrastructure Outputs:"
echo "=========================="
terraform output

# Step 10: Get IAM user credentials
echo ""
echo "🔑 IAM Deployment Users:"
echo "======================="
echo "To get access keys for deployment users:"
echo "  terraform output -json dev_access_keys"
echo ""
echo "Save these credentials securely!"
echo ""

# Step 11: Next steps
echo "📝 Next Steps:"
echo "============="
echo "1. Build and push Docker images to ECR:"
echo "   cd ../../../"
echo "   ./deploy.sh build-images dev"
echo ""
echo "2. Deploy frontend to S3:"
echo "   ./deploy.sh deploy-frontend dev"
echo ""
echo "3. Access your application:"
echo "   Frontend: https://app.$(terraform output -raw base_domain 2>/dev/null || echo 'your-domain.com')"
echo "   API: https://api.$(terraform output -raw base_domain 2>/dev/null || echo 'your-domain.com')"
echo ""
echo -e "${GREEN}🎉 Happy deploying!${NC}"
