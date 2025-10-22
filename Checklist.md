0) Chuẩn bị

 Domain có Route53 hosted zone (vd: example.com).

 Quyền AWS & OIDC GitHub Actions (assume role) cho Terraform.

 Cài: Terraform, AWS CLI, Docker, Node.js.

1) Chứng chỉ (ACM)

 Tạo ACM ở us-east-1 cho app.example.com → dùng cho CloudFront (DNS validation).

 Tạo ACM ở region chính (vd ap-southeast-1) cho app.example.com (nếu CF→ALB dùng cùng hostname) hoặc api.example.com → dùng cho ALB.

2) Biến Terraform

 Điền terraform/envs/prod/terraform.tfvars:
account_id, region, region_us_east_1=us-east-1, base_domain, cloudfront_cert_arn, alb_cert_arn, db_username, db_password, tags image (api_image_tag, ext1_image_tag, ext2_image_tag).

3) ECR & build images

 Tạo/push images: cmdb-api, cmdb-extsys1, cmdb-extsys2 (tag khớp tfvars).

 (Tuỳ chọn) image “ingest job” riêng; nếu không, tái dùng image api.

4) Hạ tầng bằng Terraform

 terraform init && terraform apply để tạo: VPC (4 subnet), ALB, ECS (api/extsys1/2), RDS, Secrets, CF+S3, EventBridge, Route53, v.v.

 Ghi lại outputs: fe_bucket, fe_distribution_id, alb_dns, rds_endpoint.

5) VPC Endpoints (để không cần NAT)

 Gateway Endpoint: S3 → attach vào route tables của private subnets.

 Interface Endpoints (ENI trong private): ecr.api, ecr.dkr, logs, secretsmanager (tuỳ kms, sts).
Mở 443 từ SG của ECS tới endpoints.

6) CloudFront (multi-origin)

 Origin #1 (S3 FE bucket, private + OAC): Default behavior /*.

 Origin #2 (ALB): Behavior /api/*, Origin protocol = HTTPS.

 Thêm secret header (vd X-From-CF: <random>) từ CF → ALB.

7) ALB listener rules (chặn truy cập trực tiếp)

 Rule #1: nếu X-From-CF không khớp → Fixed 403.

 Rule #2: nếu khớp → forward TG api:3000 (health /health).

8) ECS Fargate (api)

 Task definition: env DB_HOST, DB_USER, DB_NAME, secrets DB_PASS (Secrets Manager ARN), healthcheck /health.

 Service api desiredCount 1 (có thể nâng lên 2 sau).

 SG: ingress 3000 từ SG-ALB, egress 443 → endpoints, egress 1433 → SG-RDS.

9) RDS for SQL Server

 Single-AZ, private subnets; DB subnet group ≥ 2 subnets.

 SG-RDS: ingress 1433 từ SG-ECS.

 (Tuỳ chọn) bật Performance Insights, automated backups (≥7 ngày).

10) Secrets Manager

 Tạo secret cmdb/dbpass.

 Task execution role/task role có quyền secretsmanager:GetSecretValue (hạn chế theo ARN).

 (Tuỳ) bật rotation cho SQL Server (Lambda template).

11) EventBridge ingest

 Rule cron(0 * * * ? *) (mỗi giờ) → ECS RunTask trong private subnets, SG của service.

 Role EventBridge có ecs:RunTask + iam:PassRole.

 Gắn DLQ (SQS) cho target.

12) React FE (S3 + CloudFront)

 npm ci && npm run build → thư mục dist/.

 Upload: aws s3 sync dist/ s3://<fe_bucket>/ --delete.

 SPA fallback: CF custom error 403/404 → /index.html (200).

 Cache: assets hash max-age=31536000, immutable; index.html cache ngắn.

 Invalidate: aws cloudfront create-invalidation --distribution-id <id> --paths "/*".

13) DNS

 Route53: app.<domain> → CloudFront (ALIAS).
(Không cần api.<domain> nếu đi qua CF /api/*; nếu có, đảm bảo direct hit bị 403.)

14) CORS (chỉ nếu tách domain)

 Nếu FE gọi thẳng api.<domain> (không đi CF): bật CORS trên API:
Access-Control-Allow-Origin: https://app.<domain>.

15) Bảo mật & quan sát

 WAF gắn CloudFront (managed rules + rate-limit).

 CloudWatch Logs: /ecs/cmdb-*, ALB access logs (tuỳ chọn).

 Alarms: ALB 5xx, ECS CPU/RAM, RDS CPU/conn.

16) Kiểm tra

 https://app.<domain> render FE, refresh deep link không lỗi.

 https://app.<domain>/api/health (qua CF→ALB) 200.

 Ingest chạy theo lịch; logs không lỗi; báo cáo MA trả dữ liệu.