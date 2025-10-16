Hạ tầng nền được tổ chức theo mô hình IaC & GitOps:

1. Cloud Engineer push code lên GitHub → GitHub Actions kích hoạt pipeline.

2. GitHub Actions dùng OIDC token để gọi AWS STS AssumeRoleWithWebIdentity → assume vào các IAM Role theo env (dev/staging/prod).

3. Terraform apply:
- Provision tài nguyên AWS (EC2, RDS, Lambda, VPC, ECS, Aurora…) kèm tag bắt buộc.
- Lưu state vào S3 backend (mã hoá SSE-KMS), khoá state bằng DynamoDB table.

4. Amazon EventBridge Scheduler gọi Lambda định kỳ → Tag Reconciler rà soát & đồng bộ tag với AppRegistry.

5. AWS Resource Explorer + AWS Config cung cấp metadata để Lambda đối chiếu.

6. AWS Service Catalog AppRegistry tự động associate tài nguyên dựa trên awsApplication tag → hình thành CMDB hệ thống.