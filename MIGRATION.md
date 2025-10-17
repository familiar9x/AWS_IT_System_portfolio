# Migration Guide

Hướng dẫn migrate từ cấu trúc cũ sang cấu trúc mới.

## 📋 Overview

### Cấu trúc cũ:
```
stacks/
├── landing-zone/
├── config-aggregator/
├── logging/
├── network/
└── observability/

modules/
├── appregistry/
├── config_aggregator/
├── logging_org_trail/
├── network_shared/
└── tagging_policies/
```

### Cấu trúc mới:
```
terraform/
├── foundation/          # Tầng nền - deploy 1 lần
├── envs/{env}/         # Per environment
└── modules/            # Reusable modules
```

## 🔄 Mapping

| Cũ | Mới |
|----|-----|
| `stacks/landing-zone/` | `terraform/foundation/org-governance/` |
| `stacks/config-aggregator/` | `terraform/foundation/config-aggregator/` |
| `stacks/network/` | `terraform/envs/{env}/platform/network-stack/` |
| `stacks/logging/` | `terraform/foundation/org-governance/` (merged) |
| `modules/appregistry/` | `terraform/modules/appregistry-application/` |
| `modules/tagging_policies/` | `terraform/modules/tagging/` |

## ⚠️ QUAN TRỌNG

**KHÔNG** delete state files cũ! Migration phải được thực hiện cẩn thận:

### Option 1: Terraform State Move (Recommended)

```bash
# Ví dụ: move network stack
cd stacks/network
terraform state pull > /tmp/old-network-state.json

# Di chuyển state
cd ../../terraform/envs/dev/platform/network-stack
terraform state push /tmp/old-network-state.json

# Verify
terraform plan  # Should show no changes
```

### Option 2: Import lại (Nếu state mới)

```bash
cd terraform/envs/dev/platform/network-stack
terraform init

# Import từng resource
terraform import aws_vpc.main vpc-xxxxxxxx
terraform import aws_subnet.public[0] subnet-xxxxxxxx
# ...
```

### Option 3: Fresh deployment (Development only)

**CHỈ áp dụng cho dev/test environments!**

```bash
# Destroy cũ
cd stacks/network
terraform destroy

# Deploy mới
cd ../../terraform/envs/dev/platform/network-stack
terraform apply
```

## 📝 Checklist

- [ ] Backup tất cả state files
- [ ] Document tất cả resources hiện có
- [ ] Test migration trên dev environment trước
- [ ] Update backend config với S3 bucket mới
- [ ] Migrate state hoặc import resources
- [ ] Verify với `terraform plan` (no changes)
- [ ] Update CI/CD pipelines
- [ ] Update documentation

## 🔐 State Backup

```bash
# Backup tất cả states
cd stacks
for dir in */; do
  cd "$dir"
  if [ -f "terraform.tfstate" ]; then
    terraform state pull > "../../backups/${dir%/}-state.json"
  fi
  cd ..
done
```

## 🆕 New Features

Cấu trúc mới có thêm:

1. **Backend foundation** - S3, DynamoDB, KMS
2. **IAM OIDC** - GitHub Actions authentication
3. **Tag Reconciler** - Auto-sync tags với AppRegistry
4. **Resource Explorer** - Query resources toàn org
5. **Per-environment isolation** - Dev/Stg/Prod rõ ràng

## 📞 Support

Nếu gặp vấn đề trong quá trình migration, tham khảo:
- `terraform/README.md` - Architecture overview
- `terraform/QUICKSTART.md` - Deployment guide
- Terraform state command reference

---

**Lưu ý:** Migration nên được thực hiện từng bước, test kỹ trước khi apply lên production!
