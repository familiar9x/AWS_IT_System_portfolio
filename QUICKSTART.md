# Quick Start Guide

## 🎯 Mục tiêu

Dự án này implement **IaC + GitOps + CMDB tự động** trên AWS:
- Hạ tầng as code với Terraform
- CI/CD với GitHub Actions (OIDC authentication)
- CMDB tự động qua AppRegistry + Tag Reconciler

## 📁 Cấu trúc dự án

```
terraform/
├── foundation/           # Deploy 1 lần - hạ tầng nền toàn org
├── envs/{dev,stg,prod}/ # Các môi trường
├── modules/             # Modules tái sử dụng
└── deploy.sh            # Script deploy tự động
```

## 🚀 Deployment

### Bước 1: Foundation (Deploy 1 lần đầu)

```bash
cd terraform
./deploy.sh foundation
```

Các components được deploy theo thứ tự:
1. **Backend** - S3, DynamoDB, KMS cho state
2. **IAM OIDC** - Provider cho GitHub Actions
3. **Organizations** - AWS Orgs, OUs, Tag Policies
4. **AppRegistry** - System Catalog trung tâm
5. **Config Aggregator** - Gom config từ nhiều accounts
6. **Resource Explorer** - Index toàn org
7. **Tag Reconciler** - Lambda auto-sync tags

### Bước 2: Update backend config

Sau khi foundation deploy xong, lấy output và update backend config:

```bash
cd foundation/backend
terraform output state_bucket_name
# Copy output và update vào tất cả backend.tf files
```

### Bước 3: Deploy môi trường

```bash
# Dev environment
./deploy.sh dev

# Staging
./deploy.sh stg

# Production
./deploy.sh prod
```

## 🏷️ Tagging Requirements

**BẮT BUỘC** mọi resource phải có tags:

```hcl
module "appregistry" {
  source = "../../modules/appregistry-application"
  
  application_name = "webportal-dev"
  
  tags = {
    Environment  = "dev"
    Application  = "webportal"
    CostCenter   = "CC-001"
    BusinessUnit = "IT"
    Criticality  = "Medium"
  }
}

resource "aws_instance" "app" {
  # ...
  
  tags = merge(
    module.appregistry.application_tag,  # awsApplication tag
    {
      Name = "WebPortal App Server"
    }
  )
}
```

Tag `awsApplication` được tự động apply và Lambda sẽ reconcile với AppRegistry.

## 🔧 GitHub Actions Setup

### 1. Tạo secrets trong GitHub repo:

- `AWS_ACCOUNT_ID` - AWS account ID
- `AWS_REGION` - ap-southeast-1
- `AWS_ROLE_ARN` - ARN từ foundation/iam-oidc output

### 2. Workflow example:

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main, staging, develop]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Init & Apply
        run: |
          cd terraform/envs/${{ env.ENVIRONMENT }}
          terraform init
          terraform plan
          terraform apply -auto-approve
```

## 📊 Monitoring CMDB

### Query AppRegistry:

```bash
# List all applications
aws servicecatalog-appregistry list-applications

# Get application details
aws servicecatalog-appregistry get-application \
  --application webportal-dev

# List associated resources
aws servicecatalog-appregistry list-associated-resources \
  --application webportal-dev
```

### Query Resource Explorer:

```bash
# Search by application tag
aws resource-explorer-2 search \
  --query-string "tag.key:awsApplication tag.value:webportal-dev"

# Search all tagged resources
aws resource-explorer-2 search \
  --query-string "tag.key:awsApplication"
```

### Check Config Aggregator:

```bash
# List resources in aggregator
aws configservice list-aggregate-discovered-resources \
  --configuration-aggregator-name org-config-aggregator \
  --resource-type AWS::EC2::Instance
```

## 🔍 Tag Reconciler Lambda

Lambda chạy tự động mỗi 6 giờ và thực hiện:
1. Query Resource Explorer tìm resources có tag `awsApplication`
2. Group theo application name
3. Đối chiếu với AppRegistry
4. Auto-associate resources còn thiếu

Xem logs:

```bash
aws logs tail /aws/lambda/tag-reconciler --follow
```

Manual trigger:

```bash
aws lambda invoke \
  --function-name tag-reconciler \
  /tmp/output.json
```

## 🛠️ Development Workflow

1. Tạo feature branch
2. Thêm/sửa Terraform code
3. Test local: `terraform plan`
4. Push lên GitHub
5. GitHub Actions tự động apply
6. Lambda reconcile tags sau 6h (hoặc trigger manual)

## 📝 Best Practices

✅ Luôn dùng module `appregistry-application`  
✅ Merge `application_tag` vào mọi resource  
✅ Backend state được encrypt & version  
✅ Dùng OIDC thay vì static credentials  
✅ Config Recorder trong mỗi account  
✅ Review plan trước khi apply  
✅ Tag đầy đủ theo policy  

## 🐛 Troubleshooting

### State lock error:

```bash
# Xoá lock (CHỈ khi chắc chắn không có apply đang chạy)
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "terraform-state/path/to/state"}}'
```

### Tag không sync với AppRegistry:

```bash
# Trigger manual
aws lambda invoke \
  --function-name tag-reconciler \
  /tmp/output.json

# Xem logs
aws logs tail /aws/lambda/tag-reconciler --follow
```

### Resource Explorer không index:

```bash
# Check index status
aws resource-explorer-2 get-index

# Update index
aws resource-explorer-2 update-index-type --arn <arn> --type AGGREGATOR
```

## 📚 Next Steps

1. Customize modules trong `terraform/modules/`
2. Thêm applications trong `envs/{env}/apps/`
3. Setup monitoring & alerting
4. Implement cost optimization
5. Add compliance checks

---

**Need help?** Check `terraform/README.md` for detailed architecture.
