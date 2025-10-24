# ✅ Đã sửa tất cả lỗi Terraform syntax

## Tổng kết lỗi đã sửa:

### 1. **Lỗi duplicate output** ở `envs/dev/main.tf` và `envs/prod/main.tf`
- ❌ Có 2 output `alb_dns` trùng nhau
- ✅ Đã xóa output duplicate

### 2. **Lỗi module reference sai** 
- ❌ `module.cf_fe.distribution_host` (không tồn tại)
- ✅ Đổi thành `module.cloudfront.distribution_host`

### 3. **Lỗi variable blocks với nhiều tham số trên 1 dòng**
- ❌ `variable "tags" { type = map(string) default = {} }`
- ✅ Tách ra nhiều dòng:
```hcl
variable "tags" {
  type    = map(string)
  default = {}
}
```

Đã sửa ở các file:
- `modules/alb/main.tf`
- `modules/ai-assistant/main.tf`
- `modules/eventbridge-ingest/main.tf`
- `modules/monitoring/main.tf`
- `modules/vpc/main.tf`

### 4. **Lỗi resource blocks với nhiều tham số trên 1 dòng**

Ví dụ:
- ❌ `resource "aws_s3_bucket" "fe" { bucket = "..." force_destroy = true }`
- ✅ Tách ra nhiều dòng

Đã sửa ở các file:
- `modules/cf-s3-oac/main.tf` (S3 bucket, viewer_certificate, principals, outputs)
- `modules/rds-mssql/main.tf` (DB subnet group, security groups)
- `modules/route53-api/main.tf` (alias block)
- `modules/services/main.tf` (security groups, log groups)
- `modules/ecs/main.tf` (principals block)
- `modules/alb/main.tf` (health_check block)
- `modules/vpc/main.tf` (route, EIP blocks)

### 5. **Tổng số file đã sửa**: 14 files

## ✅ Kết quả:

```bash
terraform validate
# Success! The configuration is valid.
```

## 🚀 Bây giờ bạn có thể:

1. **Xem plan**:
```bash
terraform plan
```

2. **Deploy**:
```bash
terraform apply
```

3. **Hoặc dùng script**:
```bash
cd /home/ansible/AWS_IT_System_portfolio
./deploy-dev.sh
```

---

**Tất cả syntax errors đã được sửa! Infrastructure đã sẵn sàng deploy! ��**
