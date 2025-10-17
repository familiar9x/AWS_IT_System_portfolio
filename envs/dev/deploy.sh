#!/bin/bash

# Dev Environment - Automated Deployment Script
# Deploy all dev infrastructure in correct order

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

deploy_stack() {
    local stack_path=$1
    local stack_name=$2
    
    print_header "Deploying: $stack_name"
    
    cd "$stack_path"
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        print_error "terraform.tfvars not found in $stack_path"
        print_info "Please create terraform.tfvars before deployment"
        return 1
    fi
    
    # Initialize
    print_info "Initializing Terraform..."
    if [ -f "backend.tf" ]; then
        terraform init -backend-config=backend.tf
    else
        terraform init
    fi
    
    # Plan
    print_info "Planning deployment..."
    terraform plan -var-file=terraform.tfvars -out=tfplan
    
    # Ask for confirmation
    echo ""
    read -p "Apply this plan? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warning "Deployment cancelled by user"
        rm -f tfplan
        return 1
    fi
    
    # Apply
    print_info "Applying changes..."
    terraform apply tfplan
    rm -f tfplan
    
    # Save outputs
    if [ -f "outputs.tf" ]; then
        print_info "Saving outputs..."
        terraform output -json > outputs.json
    fi
    
    print_info "✅ $stack_name deployed successfully!"
    echo ""
    
    cd - > /dev/null
}

# Main deployment
print_header "Dev Environment Deployment"
echo ""

# Check current directory
if [ ! -d "platform" ] || [ ! -d "apps" ]; then
    print_error "Please run this script from envs/dev directory"
    exit 1
fi

# Deployment sequence
STACKS=(
    "platform/network-stack:Platform - Network Stack"
    "platform/iam-secrets:Platform - IAM & Secrets"
    "apps/webportal/app-stack:App - WebPortal"
    "apps/api-service/app-stack:App - API Service (optional)"
    "config-recorder:Config Recorder"
    "observability:Observability Stack"
)

# Deploy each stack
for stack in "${STACKS[@]}"; do
    IFS=":" read -r path name <<< "$stack"
    
    if [ -d "$path" ]; then
        deploy_stack "$path" "$name"
    else
        print_warning "Stack $path not found, skipping..."
    fi
    
    # Pause between stacks
    echo ""
    sleep 2
done

# Summary
print_header "Deployment Summary"
echo ""
print_info "All stacks deployed successfully!"
echo ""
print_info "Next steps:"
print_info "1. Verify resources in AWS Console"
print_info "2. Check AppRegistry associations"
print_info "3. Test application endpoints"
print_info "4. Monitor CloudWatch dashboards"
echo ""
print_info "Useful commands:"
echo -e "  ${GREEN}terraform output${NC} - View stack outputs"
echo -e "  ${GREEN}aws ecs list-services --cluster dev-cluster${NC} - List ECS services"
echo -e "  ${GREEN}aws elbv2 describe-load-balancers${NC} - List ALBs"
echo ""
