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
| `Environment` | dev / staging / prod            | `prod` |
| `Owner`       | Email hoặc team phụ trách      | `platform@company.com` |
| `CostCenter`  | Mã phòng ban                   | `PLT-001` |
| `BusinessUnit`| Đơn vị nghiệp vụ               | `Securities` |
| `ManagedBy`   | Công cụ quản lý                | `IaC-Terraform` |
| `DataClass`   | Phân loại dữ liệu              | `Internal` |
| `Criticality` | Mức độ quan trọng              | `High` |
| `DRTier`      | Mức độ DR                     | `Gold` |

### 📛 **Naming convention**
<environment>-<project>-<system>

yaml
Sao chép mã
Ví dụ:
- Hạ tầng: `dev-webportal-app`, `stg-webportal-db`, `prod-dwh-db`  
- IAM: `devops-pipeline-prod-role`, `ai-inference-stg-role`

---

## 🧰 Lệnh cơ bản

### 📌 Init + Plan + Apply thủ công (VD: stack network, env dev)
```bash
cd stacks/network
terraform init -backend-config=../../envs/dev/backend.hcl
terraform plan  -var-file=../../envs/dev/stacks/network/vars.tfvars
terraform apply -auto-approve -var-file=../../envs/dev/stacks/network/vars.tfvars
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

📎 Tích hợp AppRegistry (System Portfolio)
Stack appregistry tạo các Application + Attribute Group để đăng ký vào AWS Service Catalog AppRegistry.
Tất cả tài nguyên hạ tầng được gắn tag awsApplication để mapping ngược lại → phục vụ CMDB, cost allocation, compliance.

📊 Cost & Compliance
AWS Config Aggregator tổng hợp toàn bộ cấu hình → check conformance rules như required-tags.

CUR 2.0 (Data Exports) có thể thêm vào 1 stack riêng để theo dõi chi phí theo Application + Environment.

Logging Org Trail gửi toàn bộ CloudTrail về Log Archive bucket → phục vụ audit tập trung.

⚡ Mẹo cho Copilot / AI Assistant
Để Copilot hiểu repo này và hỗ trợ bạn tốt:

Giữ README này ở root repo (Copilot sẽ ưu tiên đọc).

Mỗi module/stack có file variables.tf + outputs.tf rõ ràng.

Đặt tên biến nhất quán: env, region, *_id.

Thêm comment trong main.tf mô tả mục đích resource.

Duy trì folder structure → Copilot dễ infer dependencies giữa stacks.

🚀 Next steps
 Điền các vars.tfvars thật theo tài khoản AWS của bạn.

 Tạo role platform-deployer-dev|staging|prod với trust OIDC.

 Test chạy stack network ở dev trước → sau đó triển khai tuần tự.

 Khi stable, bật auto CI/CD.

