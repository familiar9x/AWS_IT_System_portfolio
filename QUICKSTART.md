# Quick Start Guide

## Prerequisites

1. **AWS Account Setup**
   - AWS Organization enabled
   - At least 3 AWS accounts (dev, staging, prod)
   - Administrative access to management account

2. **Local Tools**
   - Terraform >= 1.5.0
   - AWS CLI configured
   - Git

3. **GitHub Setup**
   - GitHub repository
   - GitHub Actions enabled
   - OIDC provider configured in AWS

## Step 1: Configure Backend

Update the backend configuration files with your S3 bucket names:

```bash
# Edit these files:
envs/dev/backend.hcl
envs/staging/backend.hcl
envs/prod/backend.hcl
```

Create the S3 buckets and DynamoDB tables for state management:

```bash
# For each environment, create:
# - S3 bucket for Terraform state
# - DynamoDB table for state locking
# - KMS key for encryption (optional but recommended)
```

## Step 2: Configure Variables

Update the `vars.tfvars` files for each stack and environment:

```bash
# Example for dev network stack:
envs/dev/stacks/network/vars.tfvars
```

Key values to update:
- AWS account IDs
- Organization ID
- VPC CIDR blocks
- Region preferences
- Tag values (Owner, CostCenter, etc.)

## Step 3: Setup IAM Roles for GitHub Actions

Create IAM roles in each AWS account with OIDC trust relationship:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## Step 4: Deploy Stacks in Order

Deploy stacks in the following order:

### 4.1 Landing Zone (Management Account)
```bash
./scripts/deploy.sh dev landing-zone plan
./scripts/deploy.sh dev landing-zone apply
```

### 4.2 Network (Network Account)
```bash
./scripts/deploy.sh dev network plan
./scripts/deploy.sh dev network apply
```

### 4.3 Logging (Security/Audit Account)
```bash
./scripts/deploy.sh dev logging plan
./scripts/deploy.sh dev logging apply
```

### 4.4 Config Aggregator (Security Account)
```bash
./scripts/deploy.sh dev config-aggregator plan
./scripts/deploy.sh dev config-aggregator apply
```

### 4.5 Observability (Monitoring Account)
```bash
./scripts/deploy.sh dev observability plan
./scripts/deploy.sh dev observability apply
```

## Step 5: Configure GitHub Secrets

Add these secrets to your GitHub repository:

**For dev environment:**
- `AWS_DEPLOY_ROLE_ARN`: ARN of the deployment role in dev account

**For staging environment:**
- `AWS_DEPLOY_ROLE_ARN`: ARN of the deployment role in staging account

**For prod environment:**
- `AWS_DEPLOY_ROLE_ARN`: ARN of the deployment role in prod account

## Step 6: Test CI/CD Pipeline

1. Create a feature branch
2. Make a small change
3. Push and create a PR
4. Review the Terraform plan in PR comments
5. Merge to main to apply changes

## Common Commands

### Format code
```bash
./scripts/format.sh
```

### Deploy a specific stack
```bash
# Plan
./scripts/deploy.sh <env> <stack> plan

# Apply
./scripts/deploy.sh <env> <stack> apply
```

### Check current state
```bash
cd stacks/<stack>
terraform init -backend-config=../../envs/<env>/backend.hcl
terraform show
```

### Import existing resources
```bash
cd stacks/<stack>
terraform init -backend-config=../../envs/<env>/backend.hcl
terraform import -var-file=../../envs/<env>/stacks/<stack>/vars.tfvars <resource_type>.<resource_name> <resource_id>
```

## Troubleshooting

### State Lock Issues
```bash
# If state is locked, you may need to force unlock:
terraform force-unlock <LOCK_ID>
```

### Backend Migration
```bash
# If you need to migrate backend:
terraform init -migrate-state -backend-config=../../envs/<env>/backend.hcl
```

### Plan Differences
```bash
# To see detailed diff:
terraform plan -var-file=../../envs/<env>/stacks/<stack>/vars.tfvars -out=tfplan
terraform show -json tfplan | jq
```

## Security Best Practices

1. **Never commit sensitive data**
   - Use `.gitignore` for `.tfvars` files with secrets
   - Use AWS Secrets Manager or Parameter Store for secrets

2. **Enable MFA for critical roles**
   - Require MFA for production deployments

3. **Review all changes**
   - Always review Terraform plans before applying
   - Use PR reviews for all changes

4. **Monitor and audit**
   - Review CloudTrail logs regularly
   - Set up AWS Config rules
   - Enable GuardDuty

## Next Steps

1. Deploy to staging environment
2. Deploy to production environment
3. Set up monitoring and alerting
4. Configure backup and disaster recovery
5. Document runbooks for common operations
