# Terrafrom_AWS_IT_System_portfolio
# 🏗️Terrafrom_AWS_IT_System_portfolio — Terraform Infrastructure Platform (Multi-Account / Multi-Environment)

## 📌 Giới thiệu

Đây là bộ mã hạ tầng nền (platform infrastructure) dùng để triển khai **các thành phần chung cho toàn tổ chức trên AWS**, theo mô hình **multi-account** và **multi-environment** (dev / staging / prod).  

Mục tiêu:
- Thiết lập khung quản trị AWS Organizations / Control Tower cơ bản.  
- Cung cấp các dịch vụ chung: VPC shared, logging, observability, tagging policies, AWS Config aggregator, AppRegistry.  
- Làm nền để các team ứng dụng chỉ cần triển khai workload mà không phải tái dựng network, logging, guardrails mỗi nơi.

Toàn bộ hạ tầng được quản lý bằng **Terraform**, CI/CD bằng **GitHub Actions + OIDC → AssumeRole** (không dùng access key dài hạn).

---

## 🧠 Triết lý thiết kế

- **Tách rõ code & environment**  
  - `stacks/<stack>` chứa logic hạ tầng (root module)  
  - `envs/<env>/stacks/<stack>/vars.tfvars` chứa thông số môi trường (input)  
  - `envs/<env>/backend.hcl` chứa backend config riêng cho mỗi environment

- **Mỗi stack = 1 state riêng**  
  → Dễ rollback, CI/CD nhanh, scope thay đổi nhỏ, tách quyền rõ ràng.

- **Môi trường độc lập (dev / staging / prod)**  
  → Backend + var file riêng → không bao giờ trộn state giữa môi trường.

- **IaC-first / GitOps**  
  → Không clickops thủ công ở prod. Mọi thay đổi hạ tầng thông qua PR + pipeline.

---

## 📂 Cấu trúc thư mục

iac-platform/
├─ modules/ # Module nội bộ tái sử dụng
│ ├─ network_shared/
│ ├─ logging_org_trail/
│ ├─ config_aggregator/
│ ├─ tagging_policies/
│ └─ appregistry/
│
├─ stacks/ # Mỗi thư mục = 1 stack (root module / state)
│ ├─ landing-zone/ # Organizations, OU, SCP, Tag Policies
│ ├─ network/ # VPC hub, endpoints, TGW
│ ├─ logging/ # S3 log archive, CloudTrail org trail
│ ├─ observability/ # CloudWatch, OpenSearch, Grafana
│ └─ config-aggregator/ # AWS Config aggregator toàn org
│
├─ envs/ # Config theo từng môi trường
│ ├─ dev/
│ │ ├─ backend.hcl
│ │ └─ stacks/<stack>/vars.tfvars
│ ├─ staging/
│ │ ├─ backend.hcl
│ │ └─ stacks/<stack>/vars.tfvars
│ └─ prod/
│ ├─ backend.hcl
│ └─ stacks/<stack>/vars.tfvars
│
├─ .github/
│ └─ workflows/
│ └─ platform-apply.yml # CI/CD apply theo matrix env/stack
│
└─ README.md

r
Sao chép mã

---

## 📜 Naming & Tagging

### 🏷️ **Tagging bắt buộc** (theo Tag Policy)
| Key            | Mô tả                           | Ví dụ |
|---------------|----------------------------------|-------|
| `Application` | Tên ứng dụng hoặc module        | `network-shared` |
| `awsApplication` | ARN/tên AppRegistry Application | `arn:aws:...` |
| `Environment` | dev / stg / prod                | `prod` |
| `System`      | Tên hệ thống                    | `webportal` |
| `Owner`       | Email hoặc team phụ trách      | `team-app@company.com` |
| `CostCenter`  | Mã phòng ban                   | `PLT-001` |
| `BusinessUnit`| Đơn vị nghiệp vụ               | `Securities` |
| `ManagedBy`   | Công cụ quản lý                | `IaC-Terraform` |
| `DataClass`   | Phân loại dữ liệu              | `Internal` |
| `Criticality` | Mức độ quan trọng              | `High` |
| `DRTier`      | Mức độ DR                     | `Gold` |

### 📛 **Naming convention**
**Format:** `<environment>-<system>[-<component>]`

**Ví dụ:**
- **VPC:** `dev-network`, `stg-network`, `prod-network`
- **AppRegistry Application:** `webportal-dev`, `webportal-stg`, `webportal-prod`
- **S3 Bucket:** `dev-webportal-assets`, `prod-webportal-logs`
- **RDS:** `dev-webportal-db`, `stg-webportal-db`, `prod-webportal-db`
- **Lambda:** `dev-api-processor`, `prod-api-processor`

### 🎯 **Tag Standard cho Single Account với Multi-Environment**

Khi deploy nhiều môi trường (dev/stg/prod) trong **cùng 1 AWS account**, tags giúp phân biệt rõ ràng:

```hcl
# Ví dụ: Dev Environment
tags = {
  Environment     = "dev"
  System          = "webportal"
  Owner           = "team-app"
  awsApplication  = "arn:aws:servicecatalog:us-east-1:123456789012:/applications/xxxxx"  # ARN của webportal-dev
  ManagedBy       = "Terraform"
  CostCenter      = "CC-001"
}

# Ví dụ: Production Environment
tags = {
  Environment     = "prod"
  System          = "webportal"
  Owner           = "team-app"
  awsApplication  = "arn:aws:servicecatalog:us-east-1:123456789012:/applications/yyyyy"  # ARN của webportal-prod
  ManagedBy       = "Terraform"
  CostCenter      = "CC-001"
}
```

👉 **Lợi ích:** AppRegistry & Resource Explorer tự động phân nhóm tài nguyên theo "môi trường ảo" dựa trên tags này

---

## 🗂️ Terraform Backend Strategy (Single Account)

### 📦 **Backend Configuration cho Multi-Environment trong 1 Account**

Sử dụng **1 S3 bucket + 1 DynamoDB table** cho tất cả state files, phân biệt bằng `key` prefix:

```hcl
# backend.tf trong mỗi stack
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "dev/network/terraform.tfstate"    # dev/stg/prod/<stack>/terraform.tfstate
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
  }
}
```

**Cấu trúc S3 state files:**
```
my-terraform-state/
├── dev/
│   ├── network/terraform.tfstate
│   ├── webportal-app/terraform.tfstate
│   └── webportal-db/terraform.tfstate
├── stg/
│   ├── network/terraform.tfstate
│   └── webportal-app/terraform.tfstate
└── prod/
    ├── network/terraform.tfstate
    └── webportal-app/terraform.tfstate
```

**Lợi ích:**
- ✅ Quản lý tập trung trong 1 account
- ✅ State isolation rõ ràng giữa các môi trường
- ✅ Dễ backup và versioning
- ✅ Cost-effective (không cần nhiều account)

---

## 🧰 Lệnh cơ bản

### 📌 Init + Plan + Apply thủ công (VD: stack network, env dev)
```bash
cd stacks/network
terraform init -backend-config=../../envs/dev/backend.hcl
terraform plan  -var-file=../../envs/dev/stacks/network/vars.tfvars
terraform apply -auto-approve -var-file=../../envs/dev/stacks/network/vars.tfvars
```
❗ Mỗi stack cần chạy riêng, không dùng terraform apply cho toàn repo.

🔐 CI/CD Pipeline (GitHub Actions + OIDC)
File: .github/workflows/platform-apply.yml

Tự động chạy theo matrix: env = [dev, staging, prod] × stack = [landing-zone, network, ...]

Mỗi env có Role ARN riêng → cấu hình trong GitHub Environment Secrets

Trust policy AWS IAM ràng buộc repo:<ORG>/<REPO>:ref:refs/heads/main

Mẫu step:

yaml
Sao chép mã
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
    aws-region: us-east-1
🌍 Mối quan hệ các stack (Triển khai tuần tự)
pgsql
Sao chép mã
landing-zone   → tagging_policies
       ↓
   network (shared)
       ↓
 logging_org_trail  →  config-aggregator
       ↓
  observability
landing-zone: khởi tạo OU, SCP, Tag Policy → chạy đầu tiên ở management account

network: dựng VPC hub & endpoints trong network account

logging + config-aggregator: bật CloudTrail Org, AWS Config aggregator ở log/security account

observability: triển khai OpenSearch, CloudWatch central

📝 Quy trình thêm một stack mới
Tạo thư mục mới trong stacks/<new-stack>

Viết code Terraform như root module (main.tf, variables.tf, providers.tf…)

Tạo vars.tfvars trong envs/dev/stacks/<new-stack>/ (và staging/prod nếu cần)

Cập nhật pipeline (nếu muốn auto-run) → thêm vào matrix.stack

Apply dev → staging → prod theo thứ tự

🌐 Quy trình thêm môi trường mới
Tạo envs/<new-env>

Copy backend.hcl và stacks/*/vars.tfvars phù hợp

Tạo IAM Role deploy tương ứng với trust OIDC

Thêm <new-env> vào matrix trong pipeline CI/CD

## 📎 AWS Config + Resource Explorer (Single Account Setup)

### 🔍 **AWS Config Recorder**

Bật **1 Config Recorder** trong account để quét toàn bộ resources:

```hcl
resource "aws_config_configuration_recorder" "main" {
  name     = "main-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}
```

- ✅ Quét tất cả resources trong tất cả regions
- ✅ Không cần Config Aggregator (vì chỉ có 1 account)
- ✅ Track changes cho dev/stg/prod resources

### 🌐 **Resource Explorer**

Tạo **1 Resource Explorer Index (Aggregator)** cho toàn account:

```hcl
resource "aws_resourceexplorer2_index" "main" {
  type = "AGGREGATOR"
  
  tags = {
    Name = "Main Resource Explorer"
  }
}

resource "aws_resourceexplorer2_view" "by_environment" {
  name = "by-environment-view"
  
  included_property {
    name = "tags"
  }
  
  filters {
    filter_string = "tag.key:Environment"
  }
}
```

**Query examples:**
```bash
# Tìm tất cả resources của dev environment
aws resource-explorer-2 search --query-string "tag:Environment=dev"

# Tìm tất cả resources của webportal system
aws resource-explorer-2 search --query-string "tag:System=webportal"

# Tìm prod resources của webportal
aws resource-explorer-2 search --query-string "tag:Environment=prod tag:System=webportal"
```

---

## 🏢 AppRegistry Strategy (Single Account với Multi-Environment)

### 📋 **Tạo Multiple Applications cho mỗi Environment**

Trong **cùng 1 account**, tạo nhiều AppRegistry Applications, mỗi cái ứng với `environment + system`:

```hcl
# Dev Environment
resource "aws_servicecatalogappregistry_application" "webportal_dev" {
  name        = "webportal-dev"
  description = "WebPortal Application - Development Environment"
  
  tags = {
    Environment = "dev"
    System      = "webportal"
    Owner       = "team-app"
  }
}

# Staging Environment
resource "aws_servicecatalogappregistry_application" "webportal_stg" {
  name        = "webportal-stg"
  description = "WebPortal Application - Staging Environment"
  
  tags = {
    Environment = "stg"
    System      = "webportal"
    Owner       = "team-app"
  }
}

# Production Environment
resource "aws_servicecatalogappregistry_application" "webportal_prod" {
  name        = "webportal-prod"
  description = "WebPortal Application - Production Environment"
  
  tags = {
    Environment = "prod"
    System      = "webportal"
    Owner       = "team-app"
  }
}
```

### 🏷️ **Auto-Associate Resources với Tags**

Khi deploy bất kỳ resource nào (EC2, RDS, Lambda...), gắn tag `awsApplication` với ARN tương ứng:

```hcl
# Ví dụ: EC2 instance cho dev environment
resource "aws_instance" "app" {
  ami           = "ami-xxxxx"
  instance_type = "t3.medium"
  
  tags = {
    Name            = "dev-webportal-app"
    Environment     = "dev"
    System          = "webportal"
    Owner           = "team-app"
    awsApplication  = aws_servicecatalogappregistry_application.webportal_dev.arn
    ManagedBy       = "Terraform"
  }
}

# Ví dụ: RDS cho production
resource "aws_db_instance" "prod_db" {
  identifier     = "prod-webportal-db"
  engine         = "postgres"
  instance_class = "db.t3.large"
  
  tags = {
    Name            = "prod-webportal-db"
    Environment     = "prod"
    System          = "webportal"
    Owner           = "team-app"
    awsApplication  = aws_servicecatalogappregistry_application.webportal_prod.arn
    ManagedBy       = "Terraform"
  }
}
```

### 🤖 **Tag Reconciler Lambda**

Lambda tự động quét và associate resources với AppRegistry:

```python
# Tự động associate resources dựa trên tag awsApplication
def lambda_handler(event, context):
    # Query Resource Explorer
    resources = resource_explorer.search(
        QueryString='tag.key:awsApplication'
    )
    
    # Group by awsApplication tag
    for resource in resources:
        app_arn = get_tag_value(resource, 'awsApplication')
        app_name = extract_app_name(app_arn)  # e.g., webportal-dev
        
        # Associate with AppRegistry
        appregistry.associate_resource(
            application=app_name,
            resource=resource['Arn'],
            resourceType='CFN_STACK'
        )
```

👉 **Kết quả:** Mỗi Application trong AppRegistry sẽ tự động hiển thị tất cả resources của environment tương ứng → CMDB tự động!

---

## 📊 Cost & Compliance

### 💰 **Cost Allocation**

AWS Config + tags giúp theo dõi chi phí theo môi trường:

```bash
# Cost Explorer query
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Environment

# Kết quả:
# dev:  $500
# stg:  $300
# prod: $2000
```

### ✅ **Compliance Checks**

AWS Config Rules kiểm tra tags bắt buộc:

```hcl
resource "aws_config_config_rule" "required_tags" {
  name = "required-tags-check"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key = "Environment"
    tag2Key = "System"
    tag3Key = "Owner"
    tag4Key = "awsApplication"
  })
}
```

CUR 2.0 (Data Exports) có thể thêm vào 1 stack riêng để theo dõi chi phí theo Application + Environment.

Logging CloudTrail gửi logs về S3 bucket → phục vụ audit tập trung.

## 🎯 Best Practices cho Single Account Multi-Environment

### ✅ **DO's (Nên làm)**

1. ✅ **Phân biệt rõ ràng bằng naming convention**
   - Resources: `dev-webportal-app`, `prod-webportal-db`
   - AppRegistry: `webportal-dev`, `webportal-stg`, `webportal-prod`

2. ✅ **Luôn tag đầy đủ**
   - `Environment` = dev/stg/prod
   - `System` = tên hệ thống
   - `Owner` = team phụ trách
   - `awsApplication` = ARN của AppRegistry Application

3. ✅ **State isolation**
   - Dùng prefix khác nhau: `dev/`, `stg/`, `prod/`
   - 1 backend config cho mỗi môi trường

4. ✅ **Security Groups & Network isolation**
   - Tách VPC hoặc dùng Security Group riêng cho mỗi env
   - Tag rõ ràng để dễ audit

5. ✅ **Automation**
   - Tag Reconciler Lambda chạy định kỳ
   - Config Rules check compliance

### ❌ **DON'Ts (Tránh làm)**

1. ❌ **Không mix resources giữa các môi trường**
   - Không để dev và prod dùng chung RDS
   - Không để stg và prod dùng chung S3 bucket

2. ❌ **Không bỏ qua tags**
   - Mọi resource phải có tags đầy đủ
   - Không có tag → không track được trong CMDB

3. ❌ **Không dùng chung state file**
   - Mỗi env phải có state riêng
   - Tránh conflict và dễ rollback

4. ❌ **Không hardcode environment values**
   - Dùng variables và tfvars
   - Tái sử dụng code cho nhiều môi trường

---

## ⚡ Mẹo cho Copilot / AI Assistant

Để Copilot hiểu repo này và hỗ trợ bạn tốt:

1. Giữ README này ở root repo (Copilot sẽ ưu tiên đọc).

2. Mỗi module/stack có file variables.tf + outputs.tf rõ ràng.

3. Đặt tên biến nhất quán: `environment`, `system`, `region`, `*_id`.

4. Thêm comment trong main.tf mô tả mục đích resource.

5. Duy trì folder structure → Copilot dễ infer dependencies giữa stacks.

6. Document tag strategy trong README → Copilot sẽ suggest đúng tags.

## 🚀 Quick Start Guide (Single Account Multi-Environment)

### Bước 1: Setup Backend Infrastructure
```bash
# Tạo S3 bucket cho state
cd foundation/backend
terraform init
terraform apply

# Output: bucket name và DynamoDB table
```

### Bước 2: Tạo AppRegistry Applications
```bash
# Tạo Applications cho từng environment
cd foundation/appregistry-catalog
terraform init
terraform apply

# Output: ARNs của webportal-dev, webportal-stg, webportal-prod
```

### Bước 3: Setup Config & Resource Explorer
```bash
# Bật Config Recorder
cd foundation/config-recorder
terraform init
terraform apply

# Tạo Resource Explorer Index
cd foundation/resource-explorer
terraform init
terraform apply
```

### Bước 4: Deploy Resources cho từng Environment
```bash
# Dev environment
cd envs/dev/network
terraform init -backend-config=backend.tf
terraform apply -var="environment=dev"

# Staging environment
cd envs/stg/network
terraform init -backend-config=backend.tf
terraform apply -var="environment=stg"

# Production environment
cd envs/prod/network
terraform init -backend-config=backend.tf
terraform apply -var="environment=prod"
```

### Bước 5: Deploy Tag Reconciler Lambda
```bash
cd foundation/tag-reconciler
terraform init
terraform apply
```

### Bước 6: Verify CMDB
```bash
# Check AppRegistry
aws servicecatalog-appregistry list-applications

# Query resources by environment
aws resource-explorer-2 search --query-string "tag:Environment=dev"
aws resource-explorer-2 search --query-string "tag:Environment=prod"

# Check AppRegistry associations
aws servicecatalog-appregistry list-associated-resources \
  --application webportal-dev
```

---

## 🚀 Next Steps

- [ ] Điền các vars.tfvars thật theo tài khoản AWS của bạn
- [ ] Tạo IAM role `terraform-deployer` với trust OIDC
- [ ] Setup S3 backend bucket với versioning và encryption
- [ ] Test deploy stack network ở dev trước
- [ ] Verify tags và AppRegistry associations
- [ ] Deploy staging environment
- [ ] Deploy production với extra review
- [ ] Khi stable, bật auto CI/CD
- [ ] Setup CloudWatch alarms cho prod resources
- [ ] Configure backup policies cho critical resources

