# Dev Environment

## 📋 Overview

Dev environment dùng để **test pipeline, validate tagging, Terraform modules, AppRegistry và CI/CD** trước khi deploy lên stg/production.

## 🏗️ Architecture

```
Dev Environment
├── Platform Layer (Infrastructure Foundation)
│   ├── Network Stack (VPC, Subnets, IGW, NAT, Security Groups)
│   └── IAM & Secrets (IAM Roles, Secrets Manager, SSM Parameters)
│
├── Application Layer
│   ├── WebPortal (dev-webportal)
│   │   ├── ECS Fargate Spot (0.25 vCPU, 0.5 GB)
│   │   ├── Application Load Balancer
│   │   ├── ECR Repository
│   │   ├── Aurora MySQL Serverless v2 (0.5-1 ACU)
│   │   └── CloudWatch Logs + Alarms
│   │
│   └── Backoffice (backoffice-dev)
│       ├── Lambda (Arm64, Python 3.11, 256MB)
│       ├── API Gateway HTTP API
│       ├── DynamoDB (on-demand)
│       ├── X-Ray Tracing
│       └── CloudWatch Logs + Alarms
│
├── Config & CMDB
│   └── AWS Config Recorder (local)
│
└── Observability
    ├── CloudWatch Logs
    ├── CloudWatch Alarms
    ├── X-Ray Tracing
    └── CloudWatch Contributor Insights
```

## 🎯 Purpose

- **Test IaC**: Validate Terraform modules trước khi apply production
- **Test Tagging**: Verify tag enforcement và AppRegistry association
- **Test CI/CD**: Validate GitHub Actions workflows
- **Cost Optimization**: Sử dụng instance types nhỏ, auto-stop, serverless
- **Fast Iteration**: Deploy nhanh, test nhanh, rollback nhanh

## 📁 Directory Structure

```
envs/dev/
├── README.md
├── backend.hcl                    # Backend config cho dev
├── terraform.tfvars               # Global variables cho dev
│
├── platform/                      # Platform infrastructure
│   ├── network-stack/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   │
│   └── iam-secrets/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── backend.tf
│       └── terraform.tfvars
│
├── apps/                          # Application stacks
│   ├── webportal/                 # ECS Fargate + ALB + Aurora MySQL
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.tf
│   │   ├── terraform.tfvars
│   │   └── README.md
│   │
│   └── backoffice/                # Lambda + API Gateway + DynamoDB
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── backend.tf
│       ├── terraform.tfvars
│       └── README.md
│
├── config-recorder/               # Local AWS Config
│   ├── main.tf
│   └── terraform.tfvars
│
└── observability/                 # CloudWatch, X-Ray
    ├── main.tf
    └── terraform.tfvars
```

## 🚀 Deployment Order

1. **Platform - Network Stack** → VPC, Subnets, Security Groups
2. **Platform - IAM & Secrets** → IAM Roles, Secrets Manager
3. **Apps - WebPortal** → ECS Fargate + ALB + Aurora MySQL
4. **Apps - Backoffice** → Lambda + API Gateway + DynamoDB
5. **Config Recorder** → Local AWS Config
6. **Observability** → CloudWatch Logs/Alarms

### Deploy Applications

See individual application READMEs:
- [WebPortal](apps/webportal/README.md) - ECS Fargate application
- [Backoffice](apps/backoffice/README.md) - Serverless API application

## 💰 Cost Optimization for Dev

| Resource | Dev Configuration | Cost Savings |
|----------|-------------------|--------------|
| **ECS** | Fargate Spot, 0.25 vCPU, 0.5 GB RAM | ~70% cheaper |
| **RDS** | Aurora Serverless v2 (0.5-1 ACU) | Pay per use |
| **Lambda** | Arm64 architecture | ~20% cheaper |
| **NAT Gateway** | Single NAT in 1 AZ | 50% cheaper |
| **ALB** | Shared ALB for multiple apps | Consolidation |

### Auto-Stop Schedule

```bash
# Stop dev resources outside working hours
Monday-Friday: 8 AM - 8 PM (running)
Saturday-Sunday: Stopped
Nights: Stopped (8 PM - 8 AM)
```

## 🏷️ Tagging Standard

All resources in dev environment MUST have:

```hcl
tags = {
  Environment     = "dev"
  System          = "webportal"  # or "backoffice"
  Owner           = "team-app@company.com"
  awsApplication  = "arn:aws:servicecatalog:us-east-1:ACCOUNT:application/dev-webportal"
  ManagedBy       = "Terraform"
  CostCenter      = "CC-001"
  AutoStop        = "true"  # For cost optimization
}
```

**Note**: AppRegistry naming patterns:
- WebPortal: `dev-webportal` (environment-system)
- Backoffice: `backoffice-dev` (system-environment)

## 🔧 Quick Start

### Prerequisites

1. Foundation layer deployed
2. AppRegistry applications created (webportal-dev, api-service-dev)
3. Backend S3 bucket configured
4. IAM OIDC roles set up

### Deploy Platform

```bash
cd envs/dev/platform/network-stack
terraform init -backend-config=backend.tf
terraform plan
terraform apply

cd ../iam-secrets
terraform init -backend-config=backend.tf
terraform plan
terraform apply
```

### Deploy Applications

```bash
cd ../../apps/webportal/app-stack
terraform init -backend-config=backend.tf
terraform plan
terraform apply

cd ../../api-service/app-stack
terraform init -backend-config=backend.tf
terraform apply
```

### Deploy Config & Observability

```bash
cd ../../../config-recorder
terraform init -backend-config=backend.tf
terraform apply

cd ../observability
terraform init -backend-config=backend.tf
terraform apply
```

## 🧪 Testing & Validation

### Verify Tagging

```bash
# Check if all resources have required tags
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment,Values=dev \
  --query 'ResourceTagMappingList[?length(Tags) < 5]'

# Should return empty if all tagged correctly
```

### Verify AppRegistry Association

```bash
# List resources associated with webportal-dev
aws servicecatalog-appregistry list-associated-resources \
  --application webportal-dev

# Verify auto-association via tags
aws resource-explorer-2 search \
  --query-string "tag:awsApplication=webportal-dev"
```

### Test CI/CD Pipeline

```bash
# Trigger GitHub Actions workflow
gh workflow run dev-deploy.yml

# Monitor deployment
gh run watch
```

## 📊 Monitoring

### CloudWatch Dashboards

- **Platform Health**: VPC flow logs, NAT Gateway metrics
- **App Performance**: ECS/Lambda metrics, ALB response times
- **Database**: RDS/DynamoDB metrics, query performance
- **Cost**: Daily cost by service and application

### Alarms

- ECS task count < expected
- ALB 5xx errors > threshold
- RDS CPU > 80%
- Lambda errors > 10/minute
- Estimated daily cost > budget

## 🔄 CI/CD Integration

Dev environment tích hợp với GitHub Actions:

```yaml
# .github/workflows/dev-deploy.yml
name: Deploy to Dev

on:
  push:
    branches: [develop]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: dev
    
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.DEV_DEPLOY_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Terraform Apply
        run: |
          cd envs/dev/apps/webportal/app-stack
          terraform init -backend-config=backend.tf
          terraform apply -auto-approve
```

## 🎓 Best Practices

### ✅ DO

- Use small instance types (t3.micro, t3.small)
- Enable auto-stop for non-24/7 resources
- Use Aurora Serverless for databases
- Use Lambda instead of ECS when possible
- Test tagging compliance before promoting to stg
- Use Terraform workspaces for quick testing

### ❌ DON'T

- Don't use production-sized instances
- Don't run resources 24/7 unnecessarily
- Don't store production data in dev
- Don't skip tagging validation
- Don't deploy directly to production without dev testing

## 📚 References

- [Foundation Layer README](../../foundation/README.md)
- [Terraform Best Practices](../../terraform_best_practice.md)
- [Tagging Strategy](../../README.md#tagging-strategy)
- [Cost Optimization Guide](./COST_OPTIMIZATION.md)
