# 🚀 Foundation Layer - Quick Start Guide

## 📋 Prerequisites

### ✅ Required Tools
- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- Python 3.11+ (for Lambda development)
- bash shell

### ✅ AWS Permissions Required
- **AWS Organizations**: Full access (for org-governance)
- **IAM**: Create roles and policies
- **S3**: Create and manage buckets
- **DynamoDB**: Create tables
- **KMS**: Create and manage keys
- **Lambda**: Create functions
- **EventBridge**: Create rules
- **AWS Config**: Full access
- **Resource Explorer**: Full access
- **Service Catalog AppRegistry**: Full access
- **CloudTrail**: Create trails
- **Glue**: Create databases and crawlers

---

## 🏗️ Deployment Order

Foundation components **phải** được deploy theo thứ tự sau:

```
1. backend           → S3, DynamoDB, KMS cho Terraform state
2. iam-oidc          → IAM OIDC Provider cho GitHub Actions
3. org-governance    → AWS Organizations, Tag Policies, SCP
4. appregistry-catalog → AppRegistry Applications + Attribute Groups
5. config-recorder   → AWS Config Recorder
6. resource-explorer → Resource Explorer Index + Views
7. tag-reconciler    → Lambda định kỳ sync tags → AppRegistry
8. finops (optional) → CUR, CloudTrail, Cost insights
```

---

## 📝 Step-by-Step Deployment

### Step 1: Clone Repository

```bash
cd /path/to/Terraform_AWS_IT_System_portfolio
cd foundation
```

### Step 2: Configure Variables

Mỗi component cần file `terraform.tfvars`. Copy từ example:

```bash
# Backend
cd backend
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Sửa state_bucket_name theo account của bạn
```

**Lưu ý:** S3 bucket name phải **unique globally**. Đề xuất format:
```
<org>-terraform-state-<account-id>
Ví dụ: mycompany-terraform-state-123456789012
```

### Step 3: Deploy Backend (Manual)

Backend component **phải deploy thủ công** vì nó chứa state của chính nó:

```bash
cd backend
terraform init
terraform plan
terraform apply

# Lưu outputs
terraform output -json > ../backend-outputs.json
```

**Outputs quan trọng:**
- `state_bucket_name`: Dùng cho backend config của các components khác
- `dynamodb_table_name`: Dùng cho state locking
- `kms_key_id`: Dùng cho encryption

### Step 4: Configure Backend for Other Components

Tạo file `backend.tf` cho các components còn lại:

```bash
# Example: backend.tf template
cat > backend-template.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "YOUR_STATE_BUCKET_NAME"  # Từ backend output
    key            = "foundation/COMPONENT_NAME/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
  }
}
EOF
```

### Step 5: Deploy IAM OIDC

```bash
cd ../iam-oidc
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Điền github_org và github_repo

# Copy backend config
cp ../backend-template.tf backend.tf
sed -i 's/COMPONENT_NAME/iam-oidc/g' backend.tf

terraform init
terraform plan
terraform apply
```

### Step 6: Deploy Organizations & Governance

⚠️ **CHÚ Ý:** Component này chỉ chạy ở **Management Account** của AWS Organizations

```bash
cd ../org-governance
# Không cần terraform.tfvars vì dùng defaults

# Copy backend config
cp ../backend-template.tf backend.tf
sed -i 's/COMPONENT_NAME/org-governance/g' backend.tf

terraform init
terraform plan
terraform apply
```

### Step 7: Deploy AppRegistry Catalog

```bash
cd ../appregistry-catalog
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Thêm systems của bạn

# Example: systems variable
systems = [
  {
    name        = "webportal"
    description = "Web Portal Application"
    environments = ["dev", "stg", "prod"]
  }
]

# Copy backend config
cp ../backend-template.tf backend.tf
sed -i 's/COMPONENT_NAME/appregistry-catalog/g' backend.tf

terraform init
terraform plan
terraform apply

# Lưu outputs (cần cho tag-reconciler)
terraform output -json > ../appregistry-outputs.json
```

### Step 8: Deploy Config Recorder

```bash
cd ../config-recorder
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Sửa config_bucket_name

# Copy backend config
cp ../backend-template.tf backend.tf
sed -i 's/COMPONENT_NAME/config-recorder/g' backend.tf

terraform init
terraform plan
terraform apply
```

### Step 9: Deploy Resource Explorer

```bash
cd ../resource-explorer
# Không cần terraform.tfvars vì dùng defaults

# Copy backend config
cp ../backend-template.tf backend.tf
sed -i 's/COMPONENT_NAME/resource-explorer/g' backend.tf

terraform init
terraform plan
terraform apply

# Lưu outputs (cần cho tag-reconciler)
terraform output -json > ../resource-explorer-outputs.json
```

### Step 10: Deploy Tag Reconciler

```bash
cd ../tag-reconciler
cp terraform.tfvars.example terraform.tfvars

# Get Resource Explorer View ARN from outputs
RESOURCE_EXPLORER_VIEW_ARN=$(jq -r '.applications_view_arn.value' ../resource-explorer-outputs.json)

# Update terraform.tfvars
echo "resource_explorer_view_arn = \"$RESOURCE_EXPLORER_VIEW_ARN\"" > terraform.tfvars
echo "region = \"us-east-1\"" >> terraform.tfvars

# Copy backend config
cp ../backend-template.tf backend.tf
sed -i 's/COMPONENT_NAME/tag-reconciler/g' backend.tf

terraform init
terraform plan
terraform apply
```

### Step 11: Deploy FinOps (Optional)

```bash
cd ../finops
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Sửa cur_bucket_name và cloudtrail_bucket_name

# Copy backend config
cp ../backend-template.tf backend.tf
sed -i 's/COMPONENT_NAME/finops/g' backend.tf

terraform init
terraform plan
terraform apply
```

---

## 🤖 Automated Deployment

Nếu muốn deploy tất cả cùng lúc (sau khi đã config xong):

```bash
cd /path/to/Terraform_AWS_IT_System_portfolio/foundation
./deploy.sh
```

Script sẽ:
1. Check prerequisites
2. Deploy từng component theo thứ tự
3. Pause để confirm trước khi apply
4. Capture outputs

---

## ✅ Verification

### 1. Kiểm tra Backend

```bash
# List state files
aws s3 ls s3://YOUR_STATE_BUCKET_NAME/foundation/ --recursive

# Expected output:
# foundation/backend/terraform.tfstate
# foundation/iam-oidc/terraform.tfstate
# foundation/org-governance/terraform.tfstate
# ...
```

### 2. Kiểm tra Organizations

```bash
# List tag policies
aws organizations list-policies --filter TAG_POLICY

# List SCPs
aws organizations list-policies --filter SERVICE_CONTROL_POLICY
```

### 3. Kiểm tra AppRegistry

```bash
# List applications
aws servicecatalog-appregistry list-applications

# Expected: webportal-dev, webportal-stg, webportal-prod, ...
```

### 4. Kiểm tra Config Recorder

```bash
# Check Config status
aws configservice describe-configuration-recorder-status

# Should show: recording: true
```

### 5. Kiểm tra Resource Explorer

```bash
# Search for resources
aws resource-explorer-2 search --query-string "tag:Environment=dev"
```

### 6. Kiểm tra Tag Reconciler Lambda

```bash
# Test invoke
aws lambda invoke \
  --function-name tag-reconciler \
  --payload '{}' \
  response.json

cat response.json
```

### 7. Kiểm tra CloudTrail (if FinOps deployed)

```bash
# Check trail status
aws cloudtrail describe-trails
aws cloudtrail get-trail-status --name main-cloudtrail
```

---

## 🛠️ Troubleshooting

### ❌ Error: S3 bucket already exists

```bash
# Solution: Change bucket name to something unique
# In terraform.tfvars:
state_bucket_name = "your-unique-name-<random-string>"
```

### ❌ Error: Access Denied for Organizations

```bash
# Solution: Phải chạy từ Management Account
# Hoặc delegate admin permissions cho account hiện tại
aws organizations register-delegated-administrator \
  --account-id YOUR_ACCOUNT_ID \
  --service-principal config.amazonaws.com
```

### ❌ Error: Lambda deployment failed

```bash
# Solution: Check Lambda code exists
ls -la tag-reconciler/lambda/code.py

# Re-create zip manually
cd tag-reconciler/lambda
zip -r function.zip code.py
cd ../..
terraform apply
```

### ❌ Error: Resource Explorer not finding resources

```bash
# Solution: Wait for indexing (có thể mất 1-2 giờ)
# Check index status
aws resource-explorer-2 get-index
```

---

## 🔄 Updates & Maintenance

### Update Tag Policies

```bash
cd org-governance
# Edit main.tf
terraform plan
terraform apply
```

### Add New System to AppRegistry

```bash
cd appregistry-catalog
# Edit terraform.tfvars
systems = [
  # ...existing systems...
  {
    name        = "new-system"
    description = "New System"
    environments = ["dev", "prod"]
  }
]

terraform plan
terraform apply
```

### Manually Trigger Tag Reconciler

```bash
aws lambda invoke \
  --function-name tag-reconciler \
  --payload '{}' \
  /tmp/response.json

cat /tmp/response.json
```

---

## 📊 Cost Estimation

Estimated monthly costs for foundation layer:

| Component | Service | Estimated Cost |
|-----------|---------|----------------|
| Backend | S3 + DynamoDB | ~$5 |
| Config Recorder | AWS Config | ~$20-50 |
| Resource Explorer | RE Index | Free |
| Tag Reconciler | Lambda + EventBridge | <$1 |
| FinOps | CloudTrail + CUR + Glue | ~$10-20 |
| **Total** | | **~$36-76/month** |

*Actual costs depend on number of resources, regions, and usage.*

---

## 🎯 Next Steps

After foundation deployment:

1. ✅ **Verify all components** using verification steps above
2. ✅ **Configure CI/CD** with GitHub Actions using IAM OIDC roles
3. ✅ **Deploy environment infrastructure** (`envs/dev`, `envs/stg`, `envs/prod`)
4. ✅ **Tag resources** with proper tags (Environment, System, Owner, awsApplication)
5. ✅ **Monitor Cost Explorer** for tagged resources
6. ✅ **Review Config Rules** compliance status

---

## 📚 References

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [AWS Config Documentation](https://docs.aws.amazon.com/config/)
- [AWS Resource Explorer](https://docs.aws.amazon.com/resource-explorer/)
- [AppRegistry Documentation](https://docs.aws.amazon.com/servicecatalog/latest/adminguide/appregistry.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
