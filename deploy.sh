#!/bin/bash
# Deploy script cho Terraform stacks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function deploy_stack() {
    local stack_path=$1
    local stack_name=$2
    
    log_info "Deploying $stack_name..."
    
    cd "$stack_path"
    
    if [ ! -f "main.tf" ]; then
        log_error "main.tf not found in $stack_path"
        return 1
    fi
    
    log_info "Running terraform init..."
    terraform init
    
    log_info "Running terraform plan..."
    terraform plan -out=tfplan
    
    read -p "Apply this plan? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        log_info "Running terraform apply..."
        terraform apply tfplan
        rm -f tfplan
        log_info "✓ $stack_name deployed successfully"
    else
        log_warn "Deployment cancelled"
        rm -f tfplan
        return 1
    fi
    
    cd - > /dev/null
}

function deploy_foundation() {
    log_info "========================================="
    log_info "Deploying Foundation Layer"
    log_info "========================================="
    
    local base_dir="terraform/foundation"
    
    # Order matters!
    declare -a stacks=(
        "$base_dir/backend:Backend (S3, DynamoDB, KMS)"
        "$base_dir/iam-oidc:IAM OIDC Provider"
        "$base_dir/org-governance:Organizations & Governance"
        "$base_dir/appregistry-catalog:AppRegistry Catalog"
        "$base_dir/config-aggregator:Config Aggregator"
        "$base_dir/resource-explorer:Resource Explorer"
        "$base_dir/tag-reconciler:Tag Reconciler Lambda"
    )
    
    for stack in "${stacks[@]}"; do
        IFS=: read -r path name <<< "$stack"
        deploy_stack "$path" "$name" || log_error "Failed to deploy $name"
    done
}

function deploy_environment() {
    local env=$1
    
    log_info "========================================="
    log_info "Deploying $env Environment"
    log_info "========================================="
    
    local base_dir="terraform/envs/$env"
    
    # Deploy order
    deploy_stack "$base_dir/config-recorder" "Config Recorder ($env)"
    deploy_stack "$base_dir/platform/network-stack" "Network Stack ($env)"
    deploy_stack "$base_dir/platform/security-stack" "Security Stack ($env)"
    
    # Apps
    log_info "Deploy applications? (yes/no)"
    read -p "> " deploy_apps
    if [ "$deploy_apps" = "yes" ]; then
        deploy_stack "$base_dir/apps/webportal/app-stack" "WebPortal App ($env)"
        deploy_stack "$base_dir/apps/webportal/database-stack" "WebPortal DB ($env)"
    fi
    
    deploy_stack "$base_dir/observability" "Observability ($env)"
}

# Main
case "${1}" in
    foundation)
        deploy_foundation
        ;;
    dev|stg|prod)
        deploy_environment "${1}"
        ;;
    all)
        deploy_foundation
        deploy_environment "dev"
        deploy_environment "stg"
        deploy_environment "prod"
        ;;
    *)
        echo "Usage: $0 {foundation|dev|stg|prod|all}"
        echo ""
        echo "Examples:"
        echo "  $0 foundation    # Deploy foundation layer only"
        echo "  $0 dev          # Deploy dev environment"
        echo "  $0 all          # Deploy everything (use with caution!)"
        exit 1
        ;;
esac

log_info "========================================="
log_info "Deployment completed!"
log_info "========================================="
