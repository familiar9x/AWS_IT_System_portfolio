# Architecture Diagram

## 🏗️ Kiến trúc tổng quan

```
┌─────────────────────────────────────────────────────────────────┐
│                    FOUNDATION LAYER (Deploy 1 lần)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │   Backend    │  │   IAM OIDC   │  │   Organizations    │   │
│  │ S3+DDB+KMS   │  │   GitHub     │  │   OUs + Policies   │   │
│  └──────────────┘  └──────────────┘  └────────────────────┘   │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │ AppRegistry  │  │    Config    │  │    Resource        │   │
│  │   Catalog    │  │  Aggregator  │  │    Explorer        │   │
│  └──────────────┘  └──────────────┘  └────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Tag Reconciler Lambda (EventBridge Scheduler - 6h)      │  │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                │  │
│  │  │Query │→ │Group │→ │Match │→ │Assoc │                │  │
│  │  │ RE   │  │ Apps │  │ AR   │  │ Res  │                │  │
│  │  └──────┘  └──────┘  └──────┘  └──────┘                │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                               ▲
                               │
                    State (S3 + DynamoDB Lock)
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ENVIRONMENT LAYERS (dev/stg/prod)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────── PLATFORM ──────────────────────────┐  │
│  │                                                            │  │
│  │  ┌──────────────┐            ┌──────────────┐           │  │
│  │  │   Network    │            │   Security   │           │  │
│  │  │  VPC, Subnets│            │   IAM, SGs   │           │  │
│  │  └──────────────┘            └──────────────┘           │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────── APPS ──────────────────────────────┐  │
│  │                                                            │  │
│  │  ┌──────────────┐            ┌──────────────┐           │  │
│  │  │  WebPortal   │            │  BackOffice  │           │  │
│  │  │  App + DB    │            │  App + DB    │           │  │
│  │  │              │            │              │           │  │
│  │  │ ┌──────────┐ │            │ ┌──────────┐ │           │  │
│  │  │ │AppRegistry│              │ │AppRegistry│           │  │
│  │  │ │   Tag     │ │            │ │   Tag     │ │           │  │
│  │  │ └──────────┘ │            │ └──────────┘ │           │  │
│  │  └──────────────┘            └──────────────┘           │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐                            │
│  │ Observability│  │Config Recorder│                           │
│  │ CloudWatch   │  │  (Local)      │                           │
│  └──────────────┘  └──────────────┘                            │
└─────────────────────────────────────────────────────────────────┘
                               ▲
                               │
                        GitHub Actions
                        (OIDC AssumeRole)
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                          CI/CD Flow                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Developer push code → GitHub                                │
│  2. GitHub Actions (OIDC) → AssumeRole (dev/stg/prod)          │
│  3. Terraform init → S3 backend                                 │
│  4. Terraform plan → Review                                     │
│  5. Terraform apply → Create/Update resources                   │
│  6. Resources tagged with awsApplication                        │
│  7. EventBridge → Lambda (every 6h)                            │
│  8. Lambda → Query Resource Explorer                            │
│  9. Lambda → Reconcile with AppRegistry                         │
│  10. AppRegistry → CMDB updated                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow

### 1. Deployment Flow
```
GitHub → OIDC → IAM Role → Terraform → AWS Resources → Tags
```

### 2. CMDB Discovery Flow
```
Resources (tagged) → Resource Explorer (index)
                  ↓
EventBridge → Lambda Tag Reconciler
                  ↓
Query RE → Group by App → Match AppRegistry → Associate
                  ↓
            CMDB Updated
```

### 3. Config Compliance Flow
```
Resources → Config Recorder (local) → Config Aggregator (central)
                                    ↓
                              Compliance Dashboard
```

## 📊 Component Interactions

```
┌───────────────┐
│   Resources   │ ← Created by Terraform with tags
└───────┬───────┘
        │
        ├─→ Resource Explorer (indexed every hour)
        │
        ├─→ Config Recorder (changes tracked)
        │
        └─→ Tag (awsApplication)
                │
                ├─→ Lambda queries RE (every 6h)
                │
                └─→ AppRegistry (auto-associate)
                        │
                        └─→ CMDB (central view)
```

## 🏷️ Tagging Flow

```
1. Terraform creates resource
   └─→ tags = merge(module.appregistry.application_tag, {...})
        └─→ awsApplication = "dev-webportal"

2. Resource Explorer indexes resource
   └─→ Searchable by tag

3. Lambda Tag Reconciler (every 6h)
   └─→ Query: tag.key:awsApplication
   └─→ Group by tag value
   └─→ Match with AppRegistry Application
   └─→ Associate if missing

4. AppRegistry shows all resources
   └─→ CMDB view: App → Resources
```

## 🔐 Security Flow

```
GitHub Actions
     │
     ├─→ OIDC Token (no static credentials)
     │
     └─→ AWS STS AssumeRoleWithWebIdentity
              │
              ├─→ dev-terraform-deploy (for develop branch)
              ├─→ stg-terraform-deploy (for stg branch)
              └─→ prod-terraform-deploy (for main branch)
                       │
                       └─→ Terraform operations
                                │
                                └─→ State encrypted (KMS)
                                     └─→ S3 (versioned)
                                     └─→ DynamoDB (locked)
```

## 📈 Scalability

- **Foundation**: 1 deployment cho toàn org
- **Environments**: Scale theo env (dev/stg/prod)
- **Applications**: Scale theo app trong mỗi env (webportal, backoffice)
- **Resources**: Unlimited, tracked by tags

### Naming Pattern

```
{environment}-{system}-{component}

Examples:
- dev-webportal-alb
- stg-webportal-ecs
- prod-backoffice-lambda
- dev-backoffice-dynamodb
```

## 🎯 Benefits

✅ **Tách biệt concerns**: Foundation vs Environments  
✅ **Tái sử dụng**: Modules cho common patterns  
✅ **Tự động hoá**: CMDB discovery không cần manual  
✅ **Bảo mật**: OIDC thay credentials, encrypted state  
✅ **Compliance**: Config Aggregator + Tag Policies  
✅ **Visibility**: Resource Explorer + AppRegistry  

---

RE = Resource Explorer  
AR = AppRegistry  
DDB = DynamoDB

# 🧱 System Portfolio – Tech Stack Overview

This document summarizes the AWS tech stack used for both applications  
(**WebPortal** and **Backoffice**) across all environments (dev, stg, prod).  
It defines key AWS services, high availability notes, and standard tagging conventions.

---

## ⚙️ Tech Stack Summary

| **Tech Stack Layer** | **Description & AWS Services** | **Tag Example (Name + Key/Value)** |
|-----------------------|--------------------------------|------------------------------------|
| **Compute** | **Amazon ECS Fargate** runs containerized WebPortal (frontend + backend API) behind **ALB**.  <br>**AWS Lambda** powers Backoffice workloads (internal automation, admin tasks).  <br>In **prod**, enable **Auto Scaling** and **Multi-AZ** for HA. | **Name:** `prod-webportal-ecs` / `prod-backoffice-lambda`  <br>**Tags:**  <br>• Environment = prod  <br>• System = webportal / backoffice  <br>• Owner = team-app  <br>• awsApplication = arn:aws:servicecatalog:.../prod-webportal |
| **Database / Storage** | **Amazon Aurora Serverless v2 (MySQL)** for all applications.  <br>• WebPortal: Aurora MySQL Serverless v2 (0.5-4 ACU scaling)  <br>• Backoffice: DynamoDB (on-demand) for serverless API  <br>Enable **Multi-AZ** in prod. **Amazon S3** for static content, backups. | **Name:** `prod-webportal-aurora` / `prod-backoffice-dynamodb`  <br>**Tags:**  <br>• Environment = prod  <br>• System = webportal / backoffice  <br>• Owner = dba-team  <br>• DataClass = critical |
| **Network & Security** | **Dedicated VPC** per environment with public/private/database subnets.  <br>**Security Groups**, **NAT Gateway**, **Route Tables** per env.  <br>**AWS WAF**, **Shield**, **ACM certificate** for WebPortal ALB.  <br>Backoffice Lambda in private subnet. | **Name:** `prod-network-vpc` / `prod-webportal-alb-sg`  <br>**Tags:**  <br>• Environment = prod  <br>• System = network / webportal  <br>• Owner = netops  <br>• ManagedBy = terraform |
| **Observability / Logging** | **CloudWatch Logs, Metrics, Alarms**, **X-Ray** for tracing Lambda.  <br>**AWS Config**, **CloudTrail**, **Resource Explorer** for compliance.  <br>**VPC Flow Logs** for network monitoring. | **Name:** `prod-monitoring-dashboard`  <br>**Tags:**  <br>• Environment = prod  <br>• System = observability  <br>• Owner = devops  <br>• ManagedBy = terraform |
| **CI/CD & IaC** | **Terraform** manages full infra (foundation + apps).  <br>**GitHub Actions (OIDC)** handles deployment automation.  <br>No static credentials, uses IAM OIDC provider. | **Name:** `github-terraform-deploy`  <br>**Tags:**  <br>• Environment = foundation  <br>• System = cicd  <br>• Owner = devops  <br>• ManagedBy = terraform |
| **Identity & Access** | **IAM Roles** for ECS Task Execution/Task Role & Lambda Execution.  <br>**Secrets Manager** for database credentials.  <br>**SSM Parameter Store** for application config.  <br>**IAM OIDC Provider** for GitHub Actions. | **Name:** `prod-webportal-ecs-task-role` / `prod-backoffice-lambda-role`  <br>**Tags:**  <br>• Environment = prod  <br>• System = webportal / backoffice  <br>• Owner = devops |
| **CMDB / FinOps** | **AppRegistry** catalogs all systems (dev-webportal, stg-webportal, prod-webportal, etc).  <br>**Resource Explorer** for resource discovery.  <br>**Tag Reconciler Lambda** (6h schedule) auto-associates resources.  <br>**CUR + Athena** for cost analytics. | **Name:** `it-system-portfolio` / `tag-reconciler`  <br>**Tags:**  <br>• Environment = foundation  <br>• System = governance  <br>• Owner = platform-team |
| **Disaster Recovery (DR)** | **Aurora Serverless v2 Multi-AZ** in prod (automated backups 30 days).  <br>**ECS Multi-AZ deployment** (2+ AZs).  <br>**S3 Versioning** enabled for state bucket.  <br>**Aurora automated backups** with point-in-time recovery. | **Name:** `prod-webportal-aurora-backup`  <br>**Tags:**  <br>• Environment = prod  <br>• System = webportal  <br>• Owner = dba-team  <br>• DataClass = backup |

---

## 🏷️ Tagging Convention

**Naming Pattern**: `{environment}-{system}-{component}`

```hcl
tags = {
  Name            = "dev-webportal-alb"           # {env}-{system}-{component}
  Environment     = "dev"                         # dev | stg | prod
  System          = "webportal"                   # webportal | backoffice
  Owner           = "team-app@company.com"
  awsApplication  = "arn:aws:servicecatalog:us-east-1:ACCOUNT:application/dev-webportal"
  ManagedBy       = "Terraform"
  CostCenter      = "CC-001"
  Criticality     = "Medium"                      # Low | Medium | High | Critical
  AutoStop        = "true"                        # true (dev/stg) | false (prod)
}
```

**Examples**:
- **VPC**: `dev-network`, `stg-network`, `prod-network`
- **ALB**: `dev-webportal-alb`, `stg-webportal-alb`, `prod-webportal-alb`
- **ECS Service**: `dev-webportal`, `stg-webportal`, `prod-webportal`
- **Aurora**: `dev-webportal-aurora`, `stg-webportal-aurora`, `prod-webportal-aurora`
- **Lambda**: `dev-backoffice-api`, `stg-backoffice-api`, `prod-backoffice-api`
- **DynamoDB**: `dev-backoffice-data`, `stg-backoffice-data`, `prod-backoffice-data`
- **AppRegistry**: `dev-webportal`, `stg-webportal`, `prod-webportal`, `dev-backoffice`, `stg-backoffice`, `prod-backoffice`

**Database Strategy**:
- **WebPortal**: Aurora MySQL Serverless v2 (all environments)
  - dev: 0.5-1 ACU
  - stg: 0.5-2 ACU
  - prod: 1-4 ACU
- **Backoffice**: DynamoDB on-demand (all environments)
