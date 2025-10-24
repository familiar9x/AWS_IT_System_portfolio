# 🎯 Deploy môi trường DEV - TÓM TẮT NHANH

## 🚀 Cách nhanh nhất (Recommended)

```bash
# 1 lệnh duy nhất - script sẽ hướng dẫn bạn từng bước
./quick-start-dev.sh
```

## 📋 Hoặc làm thủ công (3 bước)

### Bước 1: Cấu hình AWS
```bash
aws configure
```

### Bước 2: Tạo backend + Cấu hình
```bash
# Tạo S3 + DynamoDB backend
./bootstrap-backend.sh dev

# Copy và chỉnh sửa config
cd infra_terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Sửa account_id, domain, password
```

### Bước 3: Deploy
```bash
# Về thư mục root
cd ../../..

# Chạy deploy
./deploy-dev.sh
```

## 📚 Hướng dẫn chi tiết

Đọc file: [DEPLOY_DEV.md](./DEPLOY_DEV.md)

## 🔑 Thông tin cần điền trong terraform.tfvars

```hcl
account_id        = "123456789012"           # ← AWS Account ID
region            = "us-east-1"         # ← Region của bạn
base_domain       = "dev.example.com"        # ← Domain của bạn (hoặc để example.com)
db_password       = "StrongPassword123!@#"   # ← Password mạnh

# Nếu chưa có SSL certificate, comment out 2 dòng này:
# cloudfront_cert_arn = "..."
# alb_cert_arn        = "..."

dev_users = [
  "nguyen-van-a",     # ← Tên các developers
  "tran-thi-b"
]
```

## ⏱️ Thời gian ước tính

- Setup backend: ~2 phút
- Deploy infrastructure: ~15-20 phút
- **Tổng cộng: ~20-25 phút**

## 💰 Chi phí ước tính

**~$85-170/tháng** cho môi trường DEV

Bao gồm:
- RDS SQL Server (t3.small)
- ECS Fargate (3 services)
- CloudFront + S3
- Other AWS services

## 🆘 Gặp lỗi?

### "AWS credentials not configured"
```bash
aws configure
```

### "terraform.tfvars not found"
```bash
cd infra_terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
```

### "Backend not configured"
```bash
./bootstrap-backend.sh dev
```

### "Certificate not found"
Comment out các dòng cert_arn trong terraform.tfvars

## 📞 Cần trợ giúp?

1. Đọc hướng dẫn chi tiết: `DEPLOY_DEV.md`
2. Kiểm tra logs: `aws logs tail /ecs/cmdb-dev-api --follow`
3. Xem Terraform state: `cd infra_terraform/envs/dev && terraform show`

## ✅ Sau khi deploy thành công

```bash
# Xem thông tin infrastructure
cd infra_terraform/envs/dev
terraform output

# Lấy credentials cho dev users
terraform output -json dev_access_keys > credentials.json

# Truy cập ứng dụng
# Frontend: https://app.dev.example.com
# API: https://api.dev.example.com
```

## 🗑️ Xóa môi trường

```bash
cd infra_terraform/envs/dev
terraform destroy
```

---

**Chúc bạn deploy thành công! 🎉**
