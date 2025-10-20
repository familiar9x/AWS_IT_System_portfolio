# Terraform AWS IT System Portfolio

> 🏗️ **Production-ready AWS infrastructure** với IaC + GitOps + CMDB tự động  
> 📦 **2 applications**: WebPortal (ECS Fargate + Aurora) & Backoffice (Lambda + DynamoDB)  
> 💰 **Cost-optimized**: Fargate Spot, Serverless, Arm64 

---

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- Terraform >= 1.5.0
- GitHub (for OIDC CI/CD)

### Deploy in 3 Steps

```bash

1. Firt time

cd foundation/backend
terraform init && terraform apply

BUCKET=$(terraform output -raw state_bucket_name)
find envs -name "*.hcl" -exec sed -i "s/my-terraform-state-123456789012/$BUCKET/g" {} \;


cd foundation && ./deploy.sh
cd envs/dev && ./deploy.sh


2. From second time

# 1. Deploy Foundation (one-time)
cd foundation
./deploy.sh

# 2. Deploy Dev Environment
cd ../envs/dev
terraform init && terraform apply

# 3. Deploy Applications
cd apps/webportal && terraform apply
cd ../backoffice && terraform apply
```

**See detailed guides:**
- [Foundation Deployment](#foundation-deployment)
- [Environment Deployment](#environment-deployment)



