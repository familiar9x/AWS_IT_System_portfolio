# Foundation: Deployment Script
# Script tự động deploy foundation components theo đúng thứ tự

#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to deploy a component
deploy_component() {
    local component=$1
    local component_path="$component"
    
    print_info "Deploying component: $component"
    
    cd "$component_path"
    
    # Check if tfvars exists
    if [ ! -f "terraform.tfvars" ] && [ ! -f "terraform.tfvars.example" ]; then
        print_warning "No terraform.tfvars found for $component. Skipping..."
        cd - > /dev/null
        return 0
    fi
    
    # Copy example if tfvars doesn't exist
    if [ ! -f "terraform.tfvars" ] && [ -f "terraform.tfvars.example" ]; then
        print_warning "terraform.tfvars not found. Please create one from terraform.tfvars.example"
        print_error "Deployment halted. Please configure terraform.tfvars for $component"
        exit 1
    fi
    
    # Terraform init
    print_info "Running terraform init..."
    terraform init
    
    # Terraform plan
    print_info "Running terraform plan..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    read -p "Apply this plan? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warning "Deployment cancelled by user"
        rm -f tfplan
        cd - > /dev/null
        return 1
    fi
    
    # Terraform apply
    print_info "Running terraform apply..."
    terraform apply tfplan
    rm -f tfplan
    
    print_info "Component $component deployed successfully!"
    cd - > /dev/null
}

# Main deployment sequence
print_info "Starting Foundation Layer Deployment"
echo ""

# Check if we're in the foundation directory
if [ ! -d "backend" ]; then
    print_error "Please run this script from the foundation directory"
    exit 1
fi

# Deployment order
COMPONENTS=(
    "backend"
    "iam-oidc"
    "org-governance"
    "appregistry-catalog"
    "config-recorder"
    "resource-explorer"
    "tag-reconciler"
    "finops"
)

for component in "${COMPONENTS[@]}"; do
    if [ -d "$component" ]; then
        echo ""
        print_info "========================================="
        print_info "Component: $component"
        print_info "========================================="
        deploy_component "$component"
    else
        print_warning "Component $component not found. Skipping..."
    fi
done

echo ""
print_info "========================================="
print_info "Foundation Layer Deployment Complete!"
print_info "========================================="
echo ""
print_info "Next steps:"
print_info "1. Verify all resources in AWS Console"
print_info "2. Check AppRegistry Applications are created"
print_info "3. Verify Config Recorder is active"
print_info "4. Check Resource Explorer is indexing"
print_info "5. Deploy environment-specific infrastructure (envs/)"
