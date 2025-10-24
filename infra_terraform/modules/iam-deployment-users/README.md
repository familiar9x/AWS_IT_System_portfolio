# IAM Deployment Users Guide

## Overview

This module creates IAM groups and users for environment-based deployments with appropriate permissions:

- **Dev Environment**: Limited deployment permissions for developers
- **Prod Environment**: Full deployment permissions for DevOps team

## Architecture

```
Dev Environment (envs/dev/):
├── IAM Group: cmdb-dev-deployers
│   ├── Limited ECR, ECS, S3, CloudFront permissions
│   ├── Read-only access to most AWS services
│   └── Terraform state access (read/lock)
└── Users: cmdb-dev-user1, cmdb-dev-user2, cmdb-dev-user3

Prod Environment (envs/prod/):
├── IAM Group: cmdb-devops-deployers  
│   ├── Full deployment permissions
│   ├── Complete Terraform operations
│   └── Infrastructure management access
└── Users: cmdb-devops-admin, cmdb-devops-deploy1, cmdb-devops-deploy2
```

## Permissions Comparison

### Dev Environment Permissions
- ✅ **ECR**: Push/pull container images
- ✅ **ECS**: Update services, register task definitions (dev resources only)
- ✅ **S3**: Upload frontend to dev buckets
- ✅ **CloudFront**: Invalidate cache
- ✅ **CloudWatch**: View logs and metrics
- ✅ **Terraform State**: Read state, manage locks
- ❌ **Infrastructure Changes**: Cannot create/destroy resources
- ❌ **IAM**: Cannot manage users/roles
- ❌ **Production Access**: No access to prod-tagged resources

### Prod Environment Permissions (DevOps)
- ✅ **Full ECR Access**: All container registry operations
- ✅ **Full ECS Access**: Complete orchestration control
- ✅ **Full S3 Access**: All bucket operations
- ✅ **Full Infrastructure**: Create, modify, destroy resources
- ✅ **IAM Management**: Manage roles and policies
- ✅ **Terraform Operations**: Complete state and resource management
- ✅ **All AWS Services**: Unrestricted deployment capabilities

## Configuration

### 1. Define Users in terraform.tfvars

**Dev Environment** (`envs/dev/terraform.tfvars`):
```hcl
dev_users = [
  "john-doe",
  "jane-smith",
  "bob-wilson"
]
```

**Prod Environment** (`envs/prod/terraform.tfvars`):
```hcl
prod_users = [
  "devops-lead",
  "senior-devops1",
  "senior-devops2"
]
```

### 2. Deploy IAM Resources

```bash
# Deploy dev environment IAM
cd infra_terraform/envs/dev
terraform init
terraform plan
terraform apply

# Deploy prod environment IAM
cd infra_terraform/envs/prod
terraform init
terraform plan
terraform apply
```

### 3. Retrieve Access Keys

**Important**: Access keys are sensitive! Store them securely.

```bash
# Get dev user access keys
cd infra_terraform/envs/dev
terraform output -json dev_access_keys > dev-keys.json

# Get prod user access keys
cd infra_terraform/envs/prod
terraform output -json prod_access_keys > prod-keys.json
```

### 4. Distribute Credentials Securely

**Recommended Methods**:
1. **AWS Secrets Manager**: Store keys in Secrets Manager
2. **Password Manager**: Use 1Password, LastPass, or similar
3. **Encrypted Files**: Encrypt JSON files with GPG
4. **AWS SSO**: Better alternative - no access keys needed

```bash
# Example: Encrypt credentials with GPG
gpg --encrypt --recipient devops@company.com dev-keys.json
gpg --encrypt --recipient devops@company.com prod-keys.json

# Delete plaintext files
shred -u dev-keys.json prod-keys.json
```

## User Onboarding

### For New Developer (Dev Environment)

1. **Admin creates user**:
```bash
cd infra_terraform/envs/dev
# Add username to terraform.tfvars dev_users list
terraform apply
```

2. **Retrieve and send credentials securely**:
```bash
terraform output -json dev_access_keys | jq '.["john-doe"]'
```

3. **Developer configures AWS CLI**:
```bash
aws configure --profile cmdb-dev
# Enter Access Key ID
# Enter Secret Access Key
# Region: us-east-1
# Output: json
```

4. **Test access**:
```bash
aws sts get-caller-identity --profile cmdb-dev
aws ecr describe-repositories --profile cmdb-dev
```

### For New DevOps (Prod Environment)

Same process but using prod environment configuration.

## Daily Operations

### Developer Workflow (Dev)

```bash
# 1. Build and push images
./deploy.sh build dev

# 2. Update ECS service
aws ecs update-service \
  --cluster cmdb-dev \
  --service cmdb-dev-api \
  --force-new-deployment \
  --profile cmdb-dev

# 3. Upload frontend
./deploy.sh frontend dev
```

### DevOps Workflow (Prod)

```bash
# 1. Full deployment
./deploy.sh full-deploy prod

# 2. Infrastructure changes
cd infra_terraform/envs/prod
terraform plan
terraform apply

# 3. Emergency rollback
aws ecs update-service \
  --cluster cmdb-prod \
  --service cmdb-prod-api \
  --task-definition cmdb-prod-api:123 \
  --profile cmdb-prod
```

## Security Best Practices

### 1. Rotate Access Keys Regularly

```bash
# Create new key
aws iam create-access-key --user-name cmdb-dev-user1

# Update user's configuration
# Test new key

# Delete old key
aws iam delete-access-key \
  --user-name cmdb-dev-user1 \
  --access-key-id AKIAOLD...
```

### 2. Enable MFA (Multi-Factor Authentication)

```bash
# Require MFA for sensitive operations
aws iam put-user-policy \
  --user-name cmdb-devops-admin \
  --policy-name RequireMFA \
  --policy-document file://require-mfa-policy.json
```

### 3. Monitor Access with CloudTrail

```bash
# Check user activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=cmdb-dev-user1 \
  --max-results 50
```

### 4. Use AWS SSO (Recommended)

Instead of IAM users with access keys, consider AWS SSO:
- No long-lived credentials
- Centralized user management
- Integration with corporate identity providers
- Automatic key rotation

## Troubleshooting

### Issue: User cannot push to ECR

**Check permissions**:
```bash
aws iam get-group-policy \
  --group-name cmdb-dev-deployers \
  --policy-name cmdb-dev-deploy-policy
```

**Check ECR login**:
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: Terraform state locked

**Check DynamoDB lock**:
```bash
aws dynamodb get-item \
  --table-name cmdb-terraform-state-lock \
  --key '{"LockID":{"S":"cmdb-terraform-state"}}'
```

**Force unlock** (use with caution):
```bash
cd infra_terraform/envs/dev
terraform force-unlock <LOCK_ID>
```

### Issue: Access denied to production resources

**Verify user is in correct group**:
```bash
aws iam get-groups-for-user --user-name cmdb-dev-user1
```

**Expected output**: Should only show dev groups, not prod.

## Outputs

After applying Terraform:

```bash
# Dev environment
dev_group_name        = "cmdb-dev-deployers"
dev_user_names        = ["cmdb-dev-user1", "cmdb-dev-user2", "cmdb-dev-user3"]
dev_access_keys_info  = "Dev access keys created - retrieve with: terraform output -json dev_access_keys"

# Prod environment
devops_group_name        = "cmdb-devops-deployers"
devops_user_names        = ["cmdb-devops-admin", "cmdb-devops-deploy1", "cmdb-devops-deploy2"]
devops_access_keys_info  = "DevOps access keys created - retrieve with: terraform output -json prod_access_keys"
```

## Migration to AWS SSO

For better security, migrate to AWS SSO:

1. **Enable AWS SSO** in AWS Organizations
2. **Create permission sets**:
   - `CMDBDevDeployer` (matches dev group permissions)
   - `CMDBDevOpsDeployer` (matches prod group permissions)
3. **Assign users to permission sets**
4. **Remove IAM users**: Set `create_users = false`
5. **Delete access keys**

## Support

For issues or questions:
- Check CloudTrail logs for access denials
- Review IAM policy simulator for permission testing
- Contact DevOps team for production access requests
