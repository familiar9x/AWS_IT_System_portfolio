#!/bin/bash
# Script to format all Terraform files recursively

set -e

echo "Formatting all Terraform files..."

# Format all .tf files recursively
terraform fmt -recursive .

echo "Terraform files formatted successfully!"
echo ""
echo "Changed files:"
git diff --name-only | grep -E '\.tf$' || echo "No files changed"
