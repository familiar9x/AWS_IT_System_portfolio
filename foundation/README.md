# Foundation Layer - Infrastructure as Code

## 📋 Overview

Foundation layer chứa các components được deploy **1 lần duy nhất** và dùng chung cho toàn tổ chức/account. Các components này tạo nền tảng cho việc quản lý, giám sát và tuân thủ (governance, observability, compliance).

## 🏗️ Components

| Component | Mô tả | Deploy Order |
|-----------|-------|--------------|
| **backend** | S3, DynamoDB, KMS cho Terraform state | 1️⃣ Đầu tiên |
| **iam-oidc** | IAM OIDC Provider cho GitHub Actions | 2️⃣ |
| **org-governance** | AWS Organizations, Tag Policies, SCP | 3️⃣ |
| **appregistry-catalog** | AppRegistry Applications + Attribute Groups | 4️⃣ |
| **config-recorder** | AWS Config Recorder | 5️⃣ |
| **resource-explorer** | Resource Explorer Index + Views | 6️⃣ |
| **tag-reconciler** | Lambda định kỳ sync tags → AppRegistry | 7️⃣ |
| **finops** (optional) | CUR, CloudTrail, Cost insights | 8️⃣ |

## 🚀 Deployment

### Prerequisites
- AWS CLI configured
- Terraform >= 1.5.0
- Appropriate IAM permissions

### Deploy Order

```bash
# 1. Backend (phải deploy thủ công đầu tiên)
cd backend
terraform init
terraform apply

# Lấy output để config cho các stack khác
terraform output

# 2. IAM OIDC
cd ../iam-oidc
terraform init
terraform apply

# 3. Organizations & Governance
cd ../org-governance
terraform init
terraform apply

# 4-7. Các components còn lại
cd ../appregistry-catalog && terraform init && terraform apply
cd ../config-recorder && terraform init && terraform apply
cd ../resource-explorer && terraform init && terraform apply
cd ../tag-reconciler && terraform init && terraform apply
```

## 🎯 Purpose

### 🧭 **Quản trị tổ chức**
- AWS Organizations, Tag Policies, SCP
- Enforce tag chuẩn toàn org

### 🧰 **Backend Terraform**
- S3 (state), DynamoDB (lock), KMS (SSE-KMS)
- Lưu state tập trung, lock tránh xung đột

### 🪪 **IAM & CI/CD Trust**
- IAM OIDC Provider, IAM Role (Terraform Deploy)
- Kết nối GitHub/GitLab → AssumeRole triển khai IaC

### 🧱 **Catalog trung tâm**
- AWS Service Catalog AppRegistry
- Tạo Application + Attribute Groups cho từng hệ thống/môi trường

### 🧭 **Discovery & Inventory**
- AWS Config Recorder, AWS Resource Explorer Index + View
- Gom inventory từ dev/stg/prod về, tạo CMDB trung tâm & view tìm kiếm

### 🏷 **Tag & đồng bộ**
- EventBridge Scheduler, Lambda (Tag Reconciler)
- Chạy định kỳ để chuẩn hoá tag & auto-associate vào AppRegistry

### 📊 **FinOps / Observability**
- Cost & Usage Report (CUR) → S3 + Athena + Glue
- CloudWatch Contributor Insights, CloudTrail (org trail)
- Gom chi phí & logs từ các môi trường

## 📝 Notes

- Foundation components **không bao giờ bị xóa** trong quá trình operations bình thường
- Mọi thay đổi phải qua PR review
- Backend state của foundation được lưu local hoặc trong S3 bucket khác (bootstrap)
