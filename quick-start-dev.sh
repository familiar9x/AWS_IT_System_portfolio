#!/bin/bash
# Quick Start - Deploy DEV environment
# This script helps you get started quickly

echo "🚀 CMDB DEV Environment - Quick Start"
echo "======================================"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not installed"
    echo "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not installed"
    echo "Install: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi

echo "✅ AWS CLI: $(aws --version)"
echo "✅ Terraform: $(terraform version | head -1)"
echo ""

# Check AWS credentials
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured"
    echo ""
    echo "Please run: aws configure"
    echo ""
    read -p "Do you want to configure now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws configure
    else
        exit 1
    fi
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ Connected to AWS Account: $ACCOUNT_ID"
echo ""

# Step 1: Create backend
if [ ! -f "infra_terraform/envs/dev/backend.tf" ]; then
    echo "📦 Step 1: Creating Terraform Backend..."
    echo ""
    ./bootstrap-backend.sh dev
    echo ""
else
    echo "✅ Backend already exists"
fi

# Step 2: Configure terraform.tfvars
if [ ! -f "infra_terraform/envs/dev/terraform.tfvars" ]; then
    echo "📝 Step 2: Configuring terraform.tfvars..."
    echo ""
    
    cd infra_terraform/envs/dev
    cp terraform.tfvars.example terraform.tfvars
    
    # Auto-fill account_id
    sed -i "s/123456789012/$ACCOUNT_ID/" terraform.tfvars
    
    echo "✅ Created terraform.tfvars with your Account ID"
    echo ""
    echo "⚠️  IMPORTANT: Please edit this file with your actual values:"
    echo "   - base_domain: Your domain name"
    echo "   - db_password: Strong database password"
    echo "   - cloudfront_cert_arn: Your ACM certificate ARN (or comment out)"
    echo "   - alb_cert_arn: Your ACM certificate ARN (or comment out)"
    echo "   - dev_users: List of developer names"
    echo ""
    echo "Edit command:"
    echo "   nano infra_terraform/envs/dev/terraform.tfvars"
    echo ""
    read -p "Press Enter when you're done editing..." 
    
    cd ../../..
else
    echo "✅ terraform.tfvars already exists"
fi

# Step 3: Deploy
echo ""
echo "🚀 Step 3: Ready to deploy!"
echo ""
echo "This will create AWS infrastructure including:"
echo "  - VPC (2 public + 2 private subnets)"
echo "  - ECS Fargate cluster"
echo "  - RDS SQL Server database"
echo "  - Application Load Balancer"
echo "  - CloudFront + S3 for frontend"
echo "  - IAM users for deployment"
echo "  - EventBridge automated ingest"
echo ""
echo "Estimated cost: ~$85-170/month"
echo ""
read -p "Do you want to deploy now? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    ./deploy-dev.sh
else
    echo ""
    echo "Deployment skipped. When ready, run:"
    echo "  ./deploy-dev.sh"
    echo ""
    echo "Or read the full guide:"
    echo "  cat DEPLOY_DEV.md"
fi
