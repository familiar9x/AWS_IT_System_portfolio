#!/bin/bash

# CMDB Deployment Script
# Usage: ./deploy.sh [build|deploy|destroy] [environment]

set -e

# Configuration
PROJECT_NAME="cmdb"
AWS_REGION="ap-southeast-1"
ENVIRONMENTS=("dev" "prod")
SERVICES=("api" "extsys1" "extsys2")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

get_account_id() {
    aws sts get-caller-identity --query Account --output text
}

build_and_push_images() {
    local env=$1
    local account_id=$(get_account_id)
    local ecr_base="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    log_info "Building and pushing images for environment: $env"
    
    # Get ECR login token
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ecr_base
    
    for service in "${SERVICES[@]}"; do
        log_info "Building $service..."
        
        cd "app/${service/api/api-node}"
        
        # Build image
        docker build -t "${PROJECT_NAME}-${service}:latest" .
        
        # Tag for ECR
        docker tag "${PROJECT_NAME}-${service}:latest" "${ecr_base}/${PROJECT_NAME}-${service}:latest"
        docker tag "${PROJECT_NAME}-${service}:latest" "${ecr_base}/${PROJECT_NAME}-${service}:$(date +%Y%m%d-%H%M%S)"
        
        # Push to ECR
        docker push "${ecr_base}/${PROJECT_NAME}-${service}:latest"
        docker push "${ecr_base}/${PROJECT_NAME}-${service}:$(date +%Y%m%d-%H%M%S)"
        
        log_success "$service image pushed successfully"
        cd - > /dev/null
    done
}

deploy_infrastructure() {
    local env=$1
    
    log_info "Deploying infrastructure for environment: $env"
    
    cd "infra_terraform/envs/$env"
    
    # Check if tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        log_warning "terraform.tfvars not found, copying from example"
        cp terraform.tfvars.example terraform.tfvars
        log_warning "Please edit terraform.tfvars with your configuration"
        exit 1
    fi
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    log_info "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    read -p "Do you want to apply this plan? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
        log_success "Infrastructure deployed successfully"
        
        # Show important outputs
        log_info "Important endpoints:"
        terraform output api_endpoints
        echo
        log_info "CloudWatch Dashboard:"
        terraform output cloudwatch_dashboard_url
    else
        log_info "Deployment cancelled"
    fi
    
    rm -f tfplan
    cd - > /dev/null
}

destroy_infrastructure() {
    local env=$1
    
    log_warning "This will destroy ALL infrastructure for environment: $env"
    read -p "Are you sure? Type 'yes' to confirm: " -r
    
    if [ "$REPLY" = "yes" ]; then
        cd "infra_terraform/envs/$env"
        terraform destroy
        log_success "Infrastructure destroyed"
        cd - > /dev/null
    else
        log_info "Destruction cancelled"
    fi
}

show_help() {
    echo "CMDB Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND] [ENVIRONMENT]"
    echo ""
    echo "Commands:"
    echo "  build     Build and push Docker images to ECR"
    echo "  deploy    Deploy infrastructure with Terraform"
    echo "  destroy   Destroy infrastructure"
    echo "  help      Show this help message"
    echo ""
    echo "Environments:"
    echo "  dev       Development environment"
    echo "  prod      Production environment"
    echo ""
    echo "Examples:"
    echo "  $0 build prod          # Build and push images"
    echo "  $0 deploy prod         # Deploy to production"
    echo "  $0 destroy dev         # Destroy dev environment"
}

validate_environment() {
    local env=$1
    
    if [[ ! " ${ENVIRONMENTS[@]} " =~ " ${env} " ]]; then
        log_error "Invalid environment: $env"
        log_info "Available environments: ${ENVIRONMENTS[*]}"
        exit 1
    fi
}

# Main script logic
COMMAND=${1:-help}
ENVIRONMENT=${2:-prod}

case $COMMAND in
    "build")
        check_prerequisites
        validate_environment $ENVIRONMENT
        build_and_push_images $ENVIRONMENT
        ;;
    "deploy")
        check_prerequisites
        validate_environment $ENVIRONMENT
        deploy_infrastructure $ENVIRONMENT
        ;;
    "destroy")
        check_prerequisites
        validate_environment $ENVIRONMENT
        destroy_infrastructure $ENVIRONMENT
        ;;
    "help"|*)
        show_help
        ;;
esac
