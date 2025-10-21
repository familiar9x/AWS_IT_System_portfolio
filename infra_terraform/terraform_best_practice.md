# Terraform Best Practices - AWS IT System Portfolio

> 📘 **Comprehensive guide** cho Terraform Infrastructure as Code với Single Account Multi-Environment pattern

---

## 📌 Overview

Dự án này sử dụng **Single AWS Account** với **tag-based environment separation** (dev/stg/prod), kết hợp với:

- **Foundation Layer**: Shared infrastructure (Backend, IAM OIDC, Organizations, AppRegistry, Config)
- **Environment Layers**: Isolated environments (dev/stg/prod) với platform + applications
- **CMDB Automation**: Auto-discovery qua AppRegistry + Lambda Tag Reconciler
- **GitOps CI/CD**: GitHub Actions với OIDC (no static credentials)

---

## 🏗️ Architecture Pattern

### Single Account Multi-Environment

```
AWS Account (Single)
├── Foundation Layer (deploy once)
│   ├── Backend (S3 + DynamoDB + KMS)
│   ├── IAM OIDC (GitHub trust)
│   ├── Organizations (Tag Policies, SCPs)
│   ├── AppRegistry (System catalog)
│   ├── Config (Recorder + Aggregator)
│   ├── Resource Explorer (Org-wide index)
│   ├── Tag Reconciler (Lambda 6h schedule)
│   └── FinOps (CUR, CloudTrail, Glue)
│
├── Dev Environment (tag: Environment=dev)
│   ├── Platform (VPC, IAM, Secrets)
│   └── Applications (dev-webportal, dev-backoffice)
│
├── stg Environment (tag: Environment=stg)
│   ├── Platform
│   └── Applications (stg-webportal, stg-backoffice)
│
└── Production Environment (tag: Environment=prod)
    ├── Platform
    └── Applications (prod-webportal, prod-backoffice)
```

**Key Benefits:**
- ✅ Cost-effective (1 account instead of 3)
- ✅ Simplified management
- ✅ Tag-based resource isolation
- ✅ Shared foundation infrastructure
- ✅ Easy to migrate to multi-account later

---

## 📂 Directory Structure

### Current Project Structure

```
.
├── foundation/                    # Foundation Layer (deploy once)
│   ├── backend/                   # S3 + DynamoDB + KMS for Terraform state
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   │
│   ├── iam-oidc/                  # GitHub OIDC provider
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   │
│   ├── org-governance/            # Organizations, Tag Policies, SCPs
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   │
│   ├── appregistry-catalog/       # AppRegistry Applications
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   │
│   ├── config-recorder/           # AWS Config Recorder
│   ├── config-aggregator/         # Config Aggregator
│   ├── resource-explorer/         # Resource Explorer Index
│   ├── tag-reconciler/            # Lambda auto-sync
│   ├── finops/                    # CUR, CloudTrail, Glue
│   └── deploy.sh                  # Automated deployment
│
├── envs/                          # Environment-specific configs
│   ├── dev/
│   │   ├── backend.hcl            # Backend config for dev
│   │   ├── terraform.tfvars       # Global vars for dev
│   │   │
│   │   ├── platform/
│   │   │   ├── network-stack/     # VPC, Subnets, NAT, SG
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   ├── backend.tf
│   │   │   │   └── terraform.tfvars
│   │   │   │
│   │   │   └── iam-secrets/       # IAM Roles, Secrets Manager
│   │   │       ├── main.tf
│   │   │       ├── variables.tf
│   │   │       └── terraform.tfvars
│   │   │
│   │   ├── apps/
│   │   │   ├── webportal/         # ECS Fargate + ALB + Aurora
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   ├── backend.tf
│   │   │   │   ├── terraform.tfvars
│   │   │   │   └── README.md
│   │   │   │
│   │   │   └── backoffice/        # Lambda + API Gateway + DynamoDB
│   │   │       ├── main.tf
│   │   │       ├── variables.tf
│   │   │       └── terraform.tfvars
│   │   │
│   │   ├── config-recorder/       # Local Config Recorder
│   │   ├── observability/         # CloudWatch, X-Ray
│   │   └── deploy.sh
│   │
│   ├── stg/ (same structure as dev)
│   └── prod/ (same structure as dev)
│
├── modules/                       # Reusable Terraform modules
│   ├── appregistry/
│   ├── config_aggregator/
│   ├── logging_org_trail/
│   ├── network_shared/
│   └── tagging_policies/
│
├── scripts/
│   ├── deploy.sh
│   └── format.sh
│
└── README.md
```

---

## 🎯 Design Principles

### 1. Foundation Layer (Deploy Once)

**Purpose**: Shared infrastructure across all environments

**Components**:
- Backend: Terraform state management
- IAM OIDC: CI/CD authentication
- Organizations: Governance policies
- AppRegistry: System catalog
- Config/Explorer: Resource discovery
- Tag Reconciler: CMDB automation
- FinOps: Cost tracking

**Deployment**: Manual, one-time only

```bash
cd foundation
./deploy.sh
```

### 2. Environment Layer (Per Environment)

**Purpose**: Isolated environments with shared pattern

**Components**:
- Platform: Network (VPC), IAM, Secrets
- Applications: Business workloads
- Config: Local recorder
- Observability: Monitoring

**Deployment**: Repeatable across dev/stg/prod

```bash
cd envs/dev
./deploy.sh
```

### 3. State Management

**Strategy**: One S3 bucket with prefix-based isolation

```
my-terraform-state/
├── foundation/
│   ├── backend/terraform.tfstate
│   ├── iam-oidc/terraform.tfstate
│   └── appregistry-catalog/terraform.tfstate
│
├── dev/
│   ├── platform/network/terraform.tfstate
│   ├── platform/iam-secrets/terraform.tfstate
│   ├── apps/webportal/terraform.tfstate
│   └── apps/backoffice/terraform.tfstate
│
├── stg/
│   └── ... (same structure)
│
└── prod/
    └── ... (same structure)
```

**Backend Config**:

```hcl
# envs/dev/backend.hcl
bucket         = "my-terraform-state"
key            = "dev/platform/network/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
kms_key_id     = "alias/terraform-state"
```

---

## 🏷️ Tagging Strategy

### Required Tags (Tag Policy Enforced)

| Tag Key | Description | Example | Required |
|---------|-------------|---------|----------|
| `Environment` | Environment name | `dev`, `stg`, `prod` | ✅ Yes |
| `System` | System/Application name | `webportal`, `backoffice` | ✅ Yes |
| `Owner` | Team email | `team-app@company.com` | ✅ Yes |
| `awsApplication` | AppRegistry ARN | `arn:aws:servicecatalog:...` | ✅ Yes |
| `ManagedBy` | Management tool | `Terraform` | ✅ Yes |
| `CostCenter` | Cost center code | `CC-001` | ✅ Yes |
| `Criticality` | Business criticality | `Low`, `Medium`, `High`, `Critical` | ✅ Yes |
| `AutoStop` | Auto-stop enabled | `true`, `false` | ⚠️ Optional |

### Tagging Examples

**Dev Environment:**
```hcl
tags = {
  Environment     = "dev"
  System          = "webportal"
  Owner           = "team-app@company.com"
  awsApplication  = "arn:aws:servicecatalog:us-east-1:ACCOUNT:application/dev-webportal"
  ManagedBy       = "Terraform"
  CostCenter      = "CC-001"
  Criticality     = "Medium"
  AutoStop        = "true"  # Cost optimization
}
```

**Production Environment:**
```hcl
tags = {
  Environment     = "prod"
  System          = "webportal"
  Owner           = "team-app@company.com"
  awsApplication  = "arn:aws:servicecatalog:us-east-1:ACCOUNT:application/webportal-prod"
  ManagedBy       = "Terraform"
  CostCenter      = "CC-001"
  Criticality     = "Critical"
  AutoStop        = "false"  # Always running
}
```

### Tag Usage in Terraform

```hcl
# Use locals for common tags
locals {
  common_tags = {
    Environment    = var.environment
    System         = var.system
    Owner          = var.owner
    ManagedBy      = "Terraform"
    CostCenter     = var.cost_center
  }
}

# Merge with AppRegistry tag
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  tags = merge(
    local.common_tags,
    {
      Name            = "${var.environment}-${var.system}-app"
      awsApplication  = data.terraform_remote_state.appregistry.outputs.application_arn
    }
  )
}
```

---

## 📛 Naming Convention

### Format

```
<environment>-<system>-<component>
```

### Examples by Resource Type

| Resource | Dev | stg | Production |
|----------|-----|---------|------------|
| **VPC** | `dev-network` | `stg-network` | `prod-network` |
| **Subnet** | `dev-public-1a` | `stg-public-1a` | `prod-public-1a` |
| **Security Group** | `dev-webportal-alb-sg` | `stg-webportal-alb-sg` | `prod-webportal-alb-sg` |
| **ECS Cluster** | `dev-cluster` | `stg-cluster` | `prod-cluster` |
| **ECS Service** | `dev-webportal` | `stg-webportal` | `prod-webportal` |
| **ALB** | `dev-webportal-alb` | `stg-webportal-alb` | `prod-webportal-alb` |
| **RDS** | `dev-webportal-db` | `stg-webportal-db` | `prod-webportal-db` |
| **Lambda** | `dev-backoffice-api` | `stg-backoffice-api` | `prod-backoffice-api` |
| **DynamoDB** | `dev-backoffice-data` | `stg-backoffice-data` | `prod-backoffice-data` |
| **S3 Bucket** | `dev-webportal-assets-ACCOUNT` | `stg-webportal-assets-ACCOUNT` | `prod-webportal-assets-ACCOUNT` |
| **IAM Role** | `dev-webportal-ecs-task` | `stg-webportal-ecs-task` | `prod-webportal-ecs-task` |
| **AppRegistry** | `dev-webportal` | `webportal-stg` | `webportal-prod` |

**Note**: S3 bucket names must be globally unique, include account ID

---

## 🔐 Backend Configuration

### S3 Backend Setup

```hcl
# foundation/backend/main.tf
resource "aws_s3_bucket" "terraform_state" {
  bucket = "mycompany-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Bucket"
    Purpose     = "Terraform State Storage"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "Terraform State Lock"
    Purpose   = "Terraform State Locking"
    ManagedBy = "Terraform"
  }
}
```

### Backend Config Per Environment

```hcl
# envs/dev/backend.hcl
bucket         = "mycompany-terraform-state-123456789012"
key            = "dev/apps/webportal/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
kms_key_id     = "alias/terraform-state"

# envs/stg/backend.hcl
bucket         = "mycompany-terraform-state-123456789012"
key            = "stg/apps/webportal/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
kms_key_id     = "alias/terraform-state"

# envs/prod/backend.hcl
bucket         = "mycompany-terraform-state-123456789012"
key            = "prod/apps/webportal/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
kms_key_id     = "alias/terraform-state"
```

### Usage in Terraform

```hcl
# backend.tf in each stack
terraform {
  backend "s3" {}  # Config loaded from backend.hcl
}

# Initialize with backend config
terraform init -backend-config=../../backend.hcl
```

---

## 🔄 Terraform Commands

### Basic Workflow

```bash
# 1. Initialize (load backend config)
terraform init -backend-config=../../backend.hcl

# 2. Format code
terraform fmt -recursive

# 3. Validate
terraform validate

# 4. Plan
terraform plan -var-file=terraform.tfvars -out=tfplan

# 5. Apply
terraform apply tfplan

# 6. Show outputs
terraform output

# 7. Destroy (careful!)
terraform destroy -var-file=terraform.tfvars
```

### Environment-Specific Commands

```bash
# Deploy to dev
cd envs/dev/apps/webportal
terraform init -backend-config=../../backend.hcl
terraform apply -var-file=terraform.tfvars

# Deploy to stg
cd envs/stg/apps/webportal
terraform init -backend-config=../../backend.hcl
terraform apply -var-file=terraform.tfvars

# Deploy to prod (with extra caution)
cd envs/prod/apps/webportal
terraform init -backend-config=../../backend.hcl
terraform plan -var-file=terraform.tfvars  # Review carefully
terraform apply -var-file=terraform.tfvars
```

---

## 📦 Module Best Practices

### Module Structure

```
modules/network_shared/
├── main.tf          # Main resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Terraform & provider versions
├── locals.tf        # Local values (optional)
└── README.md        # Module documentation
```

### Module Example

```hcl
# modules/network_shared/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.name}"
    }
  )
}

# modules/network_shared/variables.tf
variable "environment" {
  description = "Environment name (dev/stg/prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "Environment must be dev, stg, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR."
  }
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

# modules/network_shared/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}
```

### Module Usage

```hcl
# envs/dev/platform/network-stack/main.tf
module "network" {
  source = "../../../../modules/network_shared"

  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
  
  tags = {
    System    = "platform"
    Owner     = "infrastructure-team@company.com"
    ManagedBy = "Terraform"
  }
}
```

---

## 🤖 CMDB Automation

### AppRegistry Strategy

Create separate applications for each environment + system:

```hcl
# foundation/appregistry-catalog/main.tf
locals {
  systems      = ["webportal", "backoffice"]
  environments = ["dev", "stg", "prod"]
  
  # Generate all combinations
  applications = flatten([
    for env in local.environments : [
      for system in local.systems : {
        name = "${env}-${system}"
        env  = env
        sys  = system
      }
    ]
  ])
}

resource "aws_servicecatalogappregistry_application" "apps" {
  for_each = { for app in local.applications : app.name => app }

  name        = each.value.name
  description = "${each.value.sys} application in ${each.value.env} environment"

  tags = {
    Environment = each.value.env
    System      = each.value.sys
    ManagedBy   = "Terraform"
  }
}
```

### Tag Reconciler Lambda

```python
# foundation/tag-reconciler/lambda/code.py
import boto3
import json
from datetime import datetime

resource_explorer = boto3.client('resource-explorer-2')
appregistry = boto3.client('servicecatalog-appregistry')

def lambda_handler(event, context):
    print(f"Starting tag reconciliation at {datetime.now()}")
    
    # Query all resources with awsApplication tag
    resources = resource_explorer.search(
        QueryString='tag.key:awsApplication'
    )
    
    # Group by application
    app_resources = {}
    for resource in resources.get('Resources', []):
        app_arn = get_tag_value(resource, 'awsApplication')
        if app_arn:
            app_name = extract_app_name(app_arn)
            if app_name not in app_resources:
                app_resources[app_name] = []
            app_resources[app_name].append(resource)
    
    # Associate resources with AppRegistry
    for app_name, resources in app_resources.items():
        print(f"Processing {len(resources)} resources for {app_name}")
        
        for resource in resources:
            try:
                appregistry.associate_resource(
                    application=app_name,
                    resource=resource['Arn'],
                    resourceType='CFN_STACK'
                )
                print(f"  ✓ Associated {resource['Arn']}")
            except Exception as e:
                print(f"  ✗ Failed to associate {resource['Arn']}: {e}")
    
    return {
        'statusCode': 200,
        'body': json.dumps(f"Processed {len(app_resources)} applications")
    }
```

---

## 🔐 Security Best Practices

### 1. IAM OIDC for GitHub Actions

```hcl
# foundation/iam-oidc/main.tf
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

resource "aws_iam_role" "github_terraform_deploy" {
  name = "github-terraform-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:ORG/REPO:*"
        }
      }
    }]
  })
}
```

### 2. Secrets Management

```hcl
# envs/dev/platform/iam-secrets/main.tf
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.environment}-${var.system}-db-password"
  
  recovery_window_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.system}-db-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}
```

### 3. KMS Encryption

```hcl
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name      = "terraform-state-key"
    Purpose   = "Terraform State Encryption"
    ManagedBy = "Terraform"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}
```

---

## 💰 Cost Optimization

### Development Environment

```hcl
# Use cost-optimized resources in dev
locals {
  is_dev = var.environment == "dev"
}

# ECS Fargate Spot
resource "aws_ecs_service" "app" {
  capacity_provider_strategy {
    capacity_provider = local.is_dev ? "FARGATE_SPOT" : "FARGATE"
    weight            = 100
  }
  
  # Smaller resources in dev
  task_definition = local.is_dev ? aws_ecs_task_definition.app_small.arn : aws_ecs_task_definition.app_large.arn
}

# Lambda Arm64 (20% cheaper)
resource "aws_lambda_function" "api" {
  architectures = ["arm64"]  # Always use Arm64
  memory_size   = local.is_dev ? 256 : 512
}

# Aurora Serverless v2
resource "aws_rds_cluster" "main" {
  engine_mode = "provisioned"
  engine      = "aurora-mysql"

  serverlessv2_scaling_configuration {
    min_capacity = local.is_dev ? 0.5 : 1.0
    max_capacity = local.is_dev ? 1.0 : 4.0
  }
}

# DynamoDB on-demand (dev only)
resource "aws_dynamodb_table" "data" {
  billing_mode = local.is_dev ? "PAY_PER_REQUEST" : "PROVISIONED"
  
  read_capacity  = local.is_dev ? null : 5
  write_capacity = local.is_dev ? null : 5
}
```

### Auto-Stop Configuration

```hcl
# Tag resources for auto-stop
tags = {
  AutoStop = var.environment == "dev" ? "true" : "false"
}

# Lambda to stop/start resources based on schedule
# Schedule: Mon-Fri 8 AM - 8 PM (working hours)
```

---

## 🎯 Deployment Strategy

### 1. Foundation Deployment (One-Time)

```bash
cd foundation
./deploy.sh
```

This deploys in order:
1. Backend
2. IAM OIDC
3. Organizations
4. AppRegistry
5. Config Recorder
6. Resource Explorer
7. Tag Reconciler
8. FinOps

### 2. Environment Deployment (Repeatable)

```bash
# Dev
cd envs/dev && ./deploy.sh

# stg (after dev tested)
cd envs/stg && ./deploy.sh

# Production (with approval)
cd envs/prod && ./deploy.sh
```

### 3. Manual Deployment Order

```bash
# Platform
cd envs/dev/platform/network-stack && terraform apply
cd ../iam-secrets && terraform apply

# Applications
cd ../../apps/webportal && terraform apply
cd ../backoffice && terraform apply

# Observability
cd ../../config-recorder && terraform apply
cd ../observability && terraform apply
```

---

## ✅ Best Practices Summary

### DO's ✅

1. ✅ **Use consistent naming convention** across all resources
2. ✅ **Tag all resources** with required tags (enforced by Tag Policy)
3. ✅ **Separate state files** per stack (not per environment)
4. ✅ **Use modules** for reusable components
5. ✅ **Use OIDC** for CI/CD (no static credentials)
6. ✅ **Enable state locking** with DynamoDB
7. ✅ **Encrypt state** with KMS
8. ✅ **Use Fargate Spot** in dev/stg
9. ✅ **Use Lambda Arm64** for cost savings
10. ✅ **Enable auto-stop** in dev environment
11. ✅ **Use Secrets Manager** for sensitive data
12. ✅ **Version control** all Terraform code
13. ✅ **Document** modules and stacks
14. ✅ **Validate** with `terraform validate` and `terraform plan`
15. ✅ **Format** code with `terraform fmt -recursive`

### DON'Ts ❌

1. ❌ **Don't hardcode values** - use variables
2. ❌ **Don't skip tagging** - breaks CMDB
3. ❌ **Don't mix environments** in same state
4. ❌ **Don't use static IAM credentials** - use OIDC
5. ❌ **Don't deploy foundation multiple times**
6. ❌ **Don't use provisioned capacity** in dev
7. ❌ **Don't keep large log retention** in dev
8. ❌ **Don't share resources** between environments
9. ❌ **Don't skip backend encryption**
10. ❌ **Don't apply without plan review**

---

## 📚 Additional Resources

- [Terraform Best Practices by HashiCorp](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS AppRegistry](https://docs.aws.amazon.com/servicecatalog/latest/arguide/)
- [AWS Resource Explorer](https://docs.aws.amazon.com/resource-explorer/)

---

**Last Updated**: January 2025  
**Maintained by**: Cloud Engineering Team

