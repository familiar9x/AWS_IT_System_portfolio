# 🚀 Hướng dẫn Deploy môi trường DEV

## 📋 Yêu cầu trước khi deploy

### 1. Cài đặt công cụ cần thiết
- AWS CLI v2
- Terraform >= 1.0
- Docker
- Git

### 2. Chuẩn bị AWS Account
Bạn cần có:
- AWS Account ID
- IAM User hoặc Role có quyền tạo infrastructure
- Access Key và Secret Key (hoặc AWS SSO)

---

## 🎯 Các bước Deploy môi trường DEV

### **Bước 1: Configure AWS credentials**

```bash
# Option 1: Dùng aws configure
aws configure

# Nhập thông tin:
# AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name: us-east-1
# Default output format: json

# Option 2: Dùng environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Kiểm tra connection:**
```bash
aws sts get-caller-identity
```

Output sẽ hiển thị Account ID và User ARN của bạn.

---

### **Bước 2: Tạo Terraform Backend (S3 + DynamoDB)**

Backend này dùng để lưu trữ Terraform state file một cách an toàn.

```bash
# Chạy script bootstrap
./bootstrap-backend.sh dev
```

Script sẽ tạo:
- S3 bucket: `cmdb-terraform-state-dev-{ACCOUNT_ID}-us-east-1`
- DynamoDB table: `cmdb-terraform-state-lock-dev`
- File: `infra_terraform/envs/dev/backend.tf`

---

### **Bước 3: Cấu hình terraform.tfvars cho DEV**

```bash
cd infra_terraform/envs/dev

# Copy file example
cp terraform.tfvars.example terraform.tfvars

# Chỉnh sửa với thông tin thực của bạn
nano terraform.tfvars
```

**Nội dung cần điền:**

```hcl
# AWS Configuration
account_id        = "123456789012"              # ← Thay bằng AWS Account ID của bạn
region            = "us-east-1"            # ← Region chính (có thể giữ nguyên)
region_us_east_1  = "us-east-1"                # ← Region cho CloudFront (PHẢI là us-east-1)
name              = "cmdb-dev"                  # ← Tên project
base_domain       = "dev.example.com"           # ← Domain của bạn (nếu có)

# SSL Certificates (TẠO SAU KHI CÓ DOMAIN)
# Bước đầu có thể comment out hoặc dùng giá trị dummy
cloudfront_cert_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
alb_cert_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"

# Database Configuration
db_username = "cmdbadmin"
db_password = "DevPassword123!@#"               # ← Đổi thành password mạnh

# Docker Image Tags (ban đầu để 1.0.0)
api_image_tag  = "1.0.0"
ext1_image_tag = "1.0.0"
ext2_image_tag = "1.0.0"

# IAM Users cho Dev Team
dev_users = [
  "nguyen-van-a",     # ← Thêm tên các developers
  "tran-thi-b",
  "le-van-c"
]

tags = {
  Environment = "dev"
  Project     = "CMDB"
  ManagedBy   = "Terraform"
}
```

**⚠️ LƯU Ý QUAN TRỌNG:**

1. **account_id**: Lấy từ `aws sts get-caller-identity --query Account --output text`

2. **base_domain**: 
   - Nếu chưa có domain → dùng `dev.example.com` (sẽ không truy cập được qua domain)
   - Nếu có domain → dùng domain thật (VD: `dev.mycompany.com`)

3. **SSL Certificates**:
   - Nếu chưa có certificate → comment out 2 dòng cert_arn
   - Nếu có certificate → paste ARN thật vào

4. **db_password**: PHẢI thay đổi, tối thiểu 8 ký tự, có chữ hoa, chữ thường, số, ký tự đặc biệt

---

### **Bước 4: Deploy Infrastructure**

#### Option A: Dùng script tự động (Khuyến nghị)

```bash
# Về thư mục root của project
cd /home/ansible/AWS_IT_System_portfolio

# Chạy script deploy dev
chmod +x deploy-dev.sh
./deploy-dev.sh
```

Script sẽ:
- ✅ Kiểm tra file terraform.tfvars
- ✅ Kiểm tra AWS credentials
- ✅ Initialize Terraform
- ✅ Validate configuration
- ✅ Tạo plan
- ✅ Hỏi xác nhận trước khi apply
- ✅ Deploy infrastructure
- ✅ Hiển thị outputs

#### Option B: Deploy thủ công

```bash
cd infra_terraform/envs/dev

# 1. Initialize
terraform init

# 2. Validate
terraform validate

# 3. Plan
terraform plan -out=tfplan

# 4. Apply
terraform apply tfplan

# 5. Xem outputs
terraform output
```

---

### **Bước 5: Lấy thông tin sau khi deploy**

```bash
cd infra_terraform/envs/dev

# Xem tất cả outputs
terraform output

# Lấy IAM access keys cho dev users
terraform output -json dev_access_keys > dev-credentials.json

# Xem thông tin cụ thể
terraform output fe_bucket              # S3 bucket cho frontend
terraform output fe_distribution_id     # CloudFront distribution
terraform output alb_dns                # Application Load Balancer DNS
terraform output rds_endpoint           # Database endpoint
```

**⚠️ BẢO MẬT ACCESS KEYS:**
```bash
# Encrypt file credentials
gpg -c dev-credentials.json

# Hoặc lưu vào AWS Secrets Manager
aws secretsmanager create-secret \
  --name cmdb-dev-credentials \
  --secret-string file://dev-credentials.json

# Sau đó XÓA file gốc
shred -vfz -n 10 dev-credentials.json
```

---

## 📦 Deploy Application Code

### Bước 6: Build và Push Docker Images

```bash
# Build images cho dev
./deploy.sh build-images dev

# Hoặc build từng service
docker build -t cmdb-api:1.0.0 ./backend/api-node
docker build -t cmdb-extsys1:1.0.0 ./backend/extsys1
docker build -t cmdb-extsys2:1.0.0 ./backend/extsys2

# Tag và push to ECR
# (Chi tiết trong file deploy.sh)
```

### Bước 7: Deploy Frontend

```bash
# Deploy frontend to S3
./deploy.sh deploy-frontend dev

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(cd infra_terraform/envs/dev && terraform output -raw fe_distribution_id) \
  --paths "/*"
```

---

## 🔍 Kiểm tra và Test

### 1. Kiểm tra Health Check

```bash
# API health
curl https://api.dev.example.com/health

# External System 1
curl https://api.dev.example.com/api/extsys1/servers

# External System 2
curl https://api.dev.example.com/api/extsys2/network
```

### 2. Kiểm tra Frontend

Truy cập: `https://app.dev.example.com`

### 3. Kiểm tra Database

```bash
# Get RDS endpoint
RDS_ENDPOINT=$(cd infra_terraform/envs/dev && terraform output -raw rds_endpoint)

# Connect using SQL client
sqlcmd -S $RDS_ENDPOINT -U cmdbadmin -P 'DevPassword123!@#' -d CMDB
```

### 4. Kiểm tra CloudWatch Logs

```bash
# API logs
aws logs tail /ecs/cmdb-dev-api --follow

# EventBridge ingest logs
aws logs tail /ecs/cmdb-dev-ingest --follow
```

---

## 🛠️ Troubleshooting

### Lỗi: "AWS credentials not configured"
```bash
aws configure
# Hoặc
export AWS_ACCESS_KEY_ID="xxx"
export AWS_SECRET_ACCESS_KEY="xxx"
```

### Lỗi: "terraform.tfvars not found"
```bash
cd infra_terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

### Lỗi: "Backend not configured"
```bash
./bootstrap-backend.sh dev
```

### Lỗi: "Certificate not found"
- Option 1: Comment out `cloudfront_cert_arn` và `alb_cert_arn` trong terraform.tfvars
- Option 2: Tạo ACM certificate trước (xem hướng dẫn bên dưới)

### Lỗi: "Insufficient permissions"
- Cần IAM user/role có quyền tạo: VPC, ECS, RDS, S3, CloudFront, IAM, etc.
- Tham khảo: `infra_terraform/modules/iam-deployment-users/README.md`

---

## 📝 Tạo SSL Certificate (Optional)

### Nếu bạn có domain:

```bash
# 1. Request certificate cho CloudFront (PHẢI ở us-east-1)
aws acm request-certificate \
  --domain-name "*.dev.example.com" \
  --validation-method DNS \
  --region us-east-1

# 2. Request certificate cho ALB (ở region chính)
aws acm request-certificate \
  --domain-name "*.dev.example.com" \
  --validation-method DNS \
  --region us-east-1

# 3. Validate certificates bằng DNS
# Copy CNAME records từ ACM console và add vào Route53/DNS provider

# 4. Đợi certificate status = ISSUED
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:..." \
  --region us-east-1
```

---

## 🗑️ Xóa môi trường DEV

### Khi muốn xóa toàn bộ infrastructure:

```bash
cd infra_terraform/envs/dev

# Xóa tất cả resources
terraform destroy

# Confirm bằng cách gõ: yes
```

**⚠️ LƯU Ý:** Điều này sẽ xóa:
- VPC và tất cả networking
- ECS cluster và services
- RDS database (tất cả dữ liệu sẽ MẤT)
- S3 buckets
- CloudFront distribution
- IAM users và groups

---

## 📞 Hỗ trợ

Nếu gặp vấn đề:

1. Kiểm tra CloudWatch Logs
2. Kiểm tra Terraform state: `terraform show`
3. Review security groups: `aws ec2 describe-security-groups`
4. Check IAM permissions: `aws iam simulate-principal-policy`

---

## 🎉 Hoàn thành!

Sau khi deploy thành công, bạn sẽ có:
- ✅ Full infrastructure trên AWS
- ✅ API endpoints hoạt động
- ✅ Frontend accessible
- ✅ Database với schema
- ✅ Automated data ingest (hourly)
- ✅ IAM users cho team
- ✅ Monitoring và alerting

**Chi phí ước tính cho DEV:**
- RDS SQL Server: ~$50-100/month (db.t3.small)
- ECS Fargate: ~$20-40/month (3 services, 0.25 vCPU each)
- CloudFront: ~$5-10/month (low traffic)
- Other services: ~$10-20/month
- **TOTAL: ~$85-170/month**

**💡 TIP:** Sử dụng AWS Cost Explorer để monitor chi phí thực tế!
