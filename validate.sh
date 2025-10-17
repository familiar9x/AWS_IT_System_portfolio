#!/bin/bash
# Validate Terraform configurations

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Terraform Configuration Validator ===${NC}\n"

function validate_dir() {
    local dir=$1
    local name=$2
    
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $name - directory not found"
        return
    fi
    
    if [ ! -f "$dir/main.tf" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $name - no main.tf found"
        return
    fi
    
    echo -e "${GREEN}[CHECK]${NC} Validating $name..."
    
    cd "$dir"
    
    # Format check
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Format OK"
    else
        echo -e "  ${YELLOW}!${NC} Format issues found (run: terraform fmt)"
    fi
    
    # Init (without backend)
    if terraform init -backend=false > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Init OK"
        
        # Validate
        if terraform validate > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Validation OK"
        else
            echo -e "  ${RED}✗${NC} Validation FAILED"
            terraform validate
        fi
    else
        echo -e "  ${RED}✗${NC} Init FAILED"
    fi
    
    cd - > /dev/null
    echo ""
}

# Foundation
echo -e "${YELLOW}>>> Foundation Layer${NC}\n"
validate_dir "terraform/foundation/backend" "Backend"
validate_dir "terraform/foundation/iam-oidc" "IAM OIDC"
validate_dir "terraform/foundation/org-governance" "Organizations"
validate_dir "terraform/foundation/appregistry-catalog" "AppRegistry"
validate_dir "terraform/foundation/config-aggregator" "Config Aggregator"
validate_dir "terraform/foundation/resource-explorer" "Resource Explorer"
validate_dir "terraform/foundation/tag-reconciler" "Tag Reconciler"

# Dev Environment
echo -e "${YELLOW}>>> Dev Environment${NC}\n"
validate_dir "terraform/envs/dev/platform/network-stack" "Dev Network"
validate_dir "terraform/envs/dev/apps/webportal/app-stack" "Dev WebPortal"
validate_dir "terraform/envs/dev/config-recorder" "Dev Config Recorder"

# Modules
echo -e "${YELLOW}>>> Modules${NC}\n"
validate_dir "terraform/modules/appregistry-application" "AppRegistry Module"
validate_dir "terraform/modules/tagging" "Tagging Module"

echo -e "${GREEN}=== Validation Complete ===${NC}"
