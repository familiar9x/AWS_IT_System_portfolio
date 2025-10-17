# Terraform AWS IT System Portfolio

Hạ tầng AWS được tổ chức theo mô hình **IaC + GitOps + CMDB tự động**.

## 🏗️ Kiến trúc phân tầng

```
terraform/
├── foundation/          # Tầng nền - deploy 1 lần, dùng chung toàn org
│   ├── backend/         # S3, DynamoDB, KMS cho Terraform state
│   ├── org-governance/  # AWS Organizations, OU, Tag Policies
│   ├── iam-oidc/        # IAM OIDC provider cho GitHub Actions
│   ├── appregistry-catalog/  # System Catalog trung tâm
│   ├── config-aggregator/    # Gom Config từ nhiều account
│   ├── resource-explorer/    # Index & View toàn org
│   └── tag-reconciler/       # Lambda định kỳ reconcile tag
│
├── envs/               # Các môi trường
│   ├── dev/
│   ├── stg/
│   └── prod/
│       ├── platform/        # Network, Security
│       ├── apps/           # Applications (webportal, backoffice...)
│       ├── observability/  # CloudWatch, logs, alerts
│       └── config-recorder/  # AWS Config local
│
└── modules/            # Module tái sử dụng
    ├── vpc/
    ├── ecs/
    ├── rds/
    ├── appregistry-application/
    └── config-recorder/
```

## 🚀 Workflow CI/CD

1. **Cloud Engineer** push code lên GitHub
2. **GitHub Actions** dùng OIDC token → assume IAM Role (dev/stg/prod)
3. **Terraform** apply → provision tài nguyên AWS với tag bắt buộc
4. **EventBridge Scheduler** → trigger Lambda **Tag Reconciler** định kỳ
5. **Lambda** query Resource Explorer + Config → reconcile tag với AppRegistry
6. **AppRegistry** tự động associate tài nguyên → hình thành **CMDB**

## 📋 Deployment Order

### 1. Foundation (Deploy 1 lần)

```bash
# Step 1: Tạo backend (S3, DynamoDB, KMS)
cd terraform/foundation/backend
terraform init
terraform apply

# Step 2: Setup IAM OIDC cho GitHub Actions
cd ../iam-oidc
terraform init
terraform apply

# Step 3: AWS Organizations & Tag Policies
cd ../org-governance
terraform init
terraform apply

# Step 4: AppRegistry Catalog
cd ../appregistry-catalog
terraform init
terraform apply

# Step 5: Config Aggregator
cd ../config-aggregator
terraform init
terraform apply

# Step 6: Resource Explorer
cd ../resource-explorer
terraform init
terraform apply

# Step 7: Tag Reconciler Lambda
cd ../tag-reconciler
terraform init
terraform apply
```

### 2. Environment Stacks (Per Environment)

```bash
# Dev Environment
cd terraform/envs/dev

# Step 1: Config Recorder (bắt buộc cho aggregator)
cd config-recorder
terraform init
terraform apply

# Step 2: Platform - Network
cd ../platform/network-stack
terraform init
terraform apply

# Step 3: Platform - Security
cd ../security-stack
terraform init
terraform apply

# Step 4: Apps - WebPortal
cd ../../apps/webportal/app-stack
terraform init
terraform apply

cd ../database-stack
terraform init
terraform apply

# Step 5: Observability
cd ../../../observability
terraform init
terraform apply
```

## 🏷️ Tagging Strategy

Tất cả resources **BẮT BUỘC** phải có tag:

```hcl
tags = {
  awsApplication = "webportal-dev"    # Tự động associate với AppRegistry
  Environment    = "dev"
  CostCenter     = "CC-001"
  BusinessUnit   = "IT"
  Criticality    = "Medium"
  ManagedBy      = "Terraform"
}
```

## 🔍 CMDB Auto-Discovery

1. Resources được tag với `awsApplication`
2. **Resource Explorer** index tất cả resources
3. **Tag Reconciler Lambda** (chạy mỗi 6h) query và reconcile
4. **AppRegistry** tự động associate → CMDB trung tâm

## 🛠️ GitHub Actions Setup

```yaml
name: Terraform Deploy
on:
  push:
    branches: [main, staging, develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-southeast-1
      
      - name: Terraform Apply
        run: |
          cd terraform/envs/${{ env.ENV }}
          terraform init
          terraform apply -auto-approve
```

## 📊 Best Practices

✅ **Foundation deploy 1 lần** - không thay đổi thường xuyên  
✅ **State được mã hóa** bằng KMS và lưu trên S3  
✅ **State locking** bằng DynamoDB  
✅ **OIDC authentication** - không dùng static credentials  
✅ **Tag bắt buộc** - tự động associate với AppRegistry  
✅ **Config Recorder** trong mỗi account → aggregate về central  
✅ **Resource Explorer** index toàn org  
✅ **Lambda reconcile** định kỳ đảm bảo CMDB đồng bộ  

## 🔐 Security

- KMS encryption cho Terraform state
- S3 bucket versioning & public access block
- IAM OIDC với GitHub Actions (không dùng access keys)
- Tag Policies enforce tagging standards
- Config Aggregator giám sát compliance

## 📚 References

- [AWS AppRegistry](https://docs.aws.amazon.com/servicecatalog/latest/arguide/)
- [AWS Resource Explorer](https://docs.aws.amazon.com/resource-explorer/)
- [AWS Config Aggregator](https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)

---

**Maintained by:** Cloud Engineering Team  
**Last Updated:** October 2025
