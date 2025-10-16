#!/bin/bash
# Script to initialize and apply a Terraform stack for a specific environment

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

# Check if required parameters are provided
if [ $# -lt 2 ]; then
    print_error "Usage: $0 <environment> <stack>"
    print_info "Example: $0 dev network"
    print_info "Available environments: dev, staging, prod"
    print_info "Available stacks: landing-zone, network, logging, config-aggregator, observability"
    exit 1
fi

ENVIRONMENT=$1
STACK=$2
ACTION=${3:-plan}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_info "Valid environments are: dev, staging, prod"
    exit 1
fi

# Validate stack
if [[ ! -d "stacks/$STACK" ]]; then
    print_error "Stack directory not found: stacks/$STACK"
    exit 1
fi

# Check if vars file exists
VARS_FILE="envs/$ENVIRONMENT/stacks/$STACK/vars.tfvars"
if [[ ! -f "$VARS_FILE" ]]; then
    print_error "Variables file not found: $VARS_FILE"
    exit 1
fi

# Check if backend config exists
BACKEND_CONFIG="envs/$ENVIRONMENT/backend.hcl"
if [[ ! -f "$BACKEND_CONFIG" ]]; then
    print_error "Backend config not found: $BACKEND_CONFIG"
    exit 1
fi

print_info "=========================================="
print_info "Terraform Deployment"
print_info "Environment: $ENVIRONMENT"
print_info "Stack: $STACK"
print_info "Action: $ACTION"
print_info "=========================================="

# Change to stack directory
cd "stacks/$STACK"

# Terraform init
print_info "Running terraform init..."
terraform init -backend-config="../../$BACKEND_CONFIG" -upgrade

# Terraform format check
print_info "Checking terraform format..."
terraform fmt -check || print_warning "Some files need formatting. Run 'terraform fmt -recursive' to fix."

# Terraform validate
print_info "Running terraform validate..."
terraform validate

# Terraform plan or apply
if [ "$ACTION" = "apply" ]; then
    print_info "Running terraform plan..."
    terraform plan -var-file="../../$VARS_FILE" -out=tfplan
    
    print_warning "Review the plan above. Press Enter to continue with apply or Ctrl+C to cancel..."
    read -r
    
    print_info "Running terraform apply..."
    terraform apply tfplan
    
    print_info "Terraform apply completed successfully!"
elif [ "$ACTION" = "plan" ]; then
    print_info "Running terraform plan..."
    terraform plan -var-file="../../$VARS_FILE"
else
    print_error "Invalid action: $ACTION"
    print_info "Valid actions are: plan, apply"
    exit 1
fi

print_info "=========================================="
print_info "Deployment completed for $STACK in $ENVIRONMENT"
print_info "=========================================="
