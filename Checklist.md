## ✅ CMDB Project - Complete Implementation

### 🎯 All Components Implemented According to Architecture Specification

The project now fully implements the enterprise CMDB system with AI assistant as specified in the architecture diagrams below. All components are working together seamlessly through CloudFront's multi-origin setup.

---

## 📋 Implementation Status

### ✅ 1) Front door & delivery (one domain, zero CORS)

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



 1) Front door & delivery (one domain, zero CORS)

We run the whole product behind one CloudFront distribution with three origins so the browser never has to juggle domains:

Origin A (S3 via OAC): React SPA static files (/*).

Origin B (ALB): Core REST API (/api/*) → ECS Fargate.

Origin C (API Gateway): AI endpoint (/ai/*) → Lambda (Bedrock).

Why it matters

Single hostname → simpler cookies, no CORS headaches.

WAF on CloudFront protects all paths (static, API, AI) in one place.

Edge caching for FE assets; no caching for API/AI behaviors.

flowchart LR
  U[End User] -->|DNS| R53[Route53]
  R53 --> CF[CloudFront (WAF, TLS)]
  CF -- "/*" --> S3[(S3 FE Bucket<br/>OAC, Private)]
  CF -- "/api/*" --> ALB[ALB (HTTPS)]
  CF -- "/ai/*" --> APIGW[API Gateway (HTTP API)]


Glue details

ACM: one cert in us-east-1 for CloudFront; a second cert in the workload region for ALB.

Secret header: CloudFront injects X-From-CF → ALB listener 403 if missing (blocks direct ALB hits).

SPA fallback: CloudFront custom error 403/404 → /index.html for deep links.

2) Core microservice path (API → ECS → RDS)

The CMDB API (Node.js) runs on ECS Fargate in private subnets; ALB is public in two subnets. RDS for SQL Server sits in private subnets.

sequenceDiagram
  participant U as Browser
  participant CF as CloudFront
  participant ALB as ALB :443 (ACM)
  participant API as ECS Fargate (api)
  participant SM as Secrets Manager
  participant DB as RDS SQL Server (private)

  U->>CF: GET/POST /api/*
  CF->>ALB: HTTPS + X-From-CF
  ALB->>API: HTTP :3000 (target group)
  API->>SM: Get DB_PASS (task execution role)
  API->>DB: T-SQL (parameterized)
  DB-->>API: rows
  API-->>CF: JSON
  CF-->>U: JSON


Glue details

Security Groups: ALB:443 → ECS:3000; ECS → RDS:1433.

Secrets Manager passes DB creds to the task as container secrets (never baked into images).

VPC Endpoints (optional, no-NAT mode): ECR API/DKR, CloudWatch Logs, Secrets Manager, S3 Gateway → ECS tasks pull images, log, and fetch secrets without NAT.

IaC: ECS services, task definitions, target groups, listeners, SG rules are all Terraform’d.

3) AI over live data (safe, template-based)

Natural-language Q&A uses Bedrock, but never lets the model output raw SQL. Lambda gets an intent+params JSON, then executes a whitelisted, parameterized SQL with a read-only DB user.

sequenceDiagram
  participant U as Browser
  participant CF as CloudFront
  participant GW as API Gateway /ai/ask
  participant L as Lambda (container, VPC)
  participant BR as Bedrock Runtime
  participant SM as Secrets Manager
  participant DB as RDS SQL Server (RO)

  U->>CF: POST /ai/ask { q }
  CF->>GW: HTTPS
  GW->>L: Invoke (payload)
  L->>BR: InvokeModel (force JSON: {intent, params})
  BR-->>L: {intent, params}
  L->>SM: GetSecretValue (DB creds)
  L->>DB: Run templated SQL (RO user)
  DB-->>L: rows
  L-->>GW: JSON {intent, rows}
  GW-->>CF: 200
  CF-->>U: 200


Glue details

Lambda as a container so we can bundle msodbcsql17/pyodbc or mssql drivers.

VPC config on Lambda to talk to RDS (ENIs in private subnets).

VPCEs or NAT: Lambda reaches Bedrock/Secrets/Logs via VPC Endpoints (preferred) or NAT if you keep it simple.

Guardrails: intent whitelist, param validation, TOP/LIMIT & timeouts, plus read-only principal on RDS (often via views).

4) Automated ingest (two external systems → CMDB)

We model “other systems” as HTTP sources. EventBridge triggers an hourly RunTask on ECS Fargate to fetch, validate, and upsert.

sequenceDiagram
  participant EVB as EventBridge (cron)
  participant ING as ECS Task (ingest)
  participant EXT1 as External System 1
  participant EXT2 as External System 2
  participant SM as Secrets Manager
  participant DB as RDS SQL Server

  EVB->>ING: RunTask (Fargate)
  ING->>SM: API keys / DB pass
  ING->>EXT1: GET devices/contracts
  ING->>EXT2: GET devices/contracts
  ING->>DB: MERGE / UPSERT (Devices, MA)
  ING-->>EVB: Logs/metrics (CloudWatch)


Glue details

IAM for EventBridge: ecs:RunTask + iam:PassRole (task & exec roles only).

Retry/DLQ: CloudWatch/EventBridge target with retries and SQS DLQ (optional).

Merge policy on serial/asset tag with audit entries recorded to DeviceChanges.

5) Putting it all together (component diagram)
flowchart TB
  subgraph Edge
    R53[Route53]
    CF[CloudFront + WAF + TLS]
  end

  subgraph VPC
    IGW[Internet Gateway]
    subgraph Public Subnets
      ALB[ALB (HTTPS)]
    end
    subgraph Private Subnets
      ECS[ECS Fargate: api + ingest]
      LBD[Lambda: sql-assistant]
      RDS[(RDS: SQL Server)]
      VPCE1[[VPCE: ecr.api/ecr.dkr]]
      VPCE2[[VPCE: logs]]
      VPCE3[[VPCE: secretsmanager]]
      VPCE4[[VPCE: bedrock-runtime (opt)]]
      RT[Route Tables]
    end
  end

  S3[(S3: FE bucket\nOAC, private)]
  APIGW[API Gateway /ai]
  BR[Bedrock Runtime]
  SM[Secrets Manager]
  ECR[ECR Repos]
  CW[CloudWatch Logs]
  EVB[EventBridge]
  ACM_Cf[ACM (us-east-1)]
  ACM_ALB[ACM (region)]
  
  R53 --> CF
  CF -->|/*| S3
  CF -->|/api/*| ALB
  CF -->|/ai/*| APIGW
  ALB --> ECS --> RDS
  EVB --> ECS
  LBD --> RDS
  APIGW --> LBD
  LBD --> BR
  ECS --> ECR
  ECS --> CW
  LBD --> CW
  ECS --> SM
  LBD --> SM
  CF -.-> ACM_Cf
  ALB -.-> ACM_ALB
  VPCE1 -. private -.-> ECS
  VPCE2 -. private -.-> ECS
  VPCE3 -. private -.-> ECS
  VPCE4 -. private -.-> LBD