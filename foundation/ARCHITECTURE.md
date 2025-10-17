# Foundation Layer Architecture

## 🏗️ Component Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FOUNDATION LAYER                                │
│                  (Deploy once, shared across all environments)          │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│   1. BACKEND         │
│  ─────────────────   │
│  • S3 Bucket         │───┐
│  • DynamoDB Lock     │   │
│  • KMS Key           │   │
└──────────────────────┘   │
                           │  Stores state for
┌──────────────────────┐   │  all other components
│   2. IAM OIDC        │   │
│  ─────────────────   │   │
│  • OIDC Provider     │◄──┤
│  • Deploy Roles      │   │
│    - dev-role        │   │
│    - stg-role        │   │
│    - prod-role       │   │
└──────────────────────┘   │
         │                 │
         │ Trust from      │
         │ GitHub Actions  │
         ▼                 │
┌──────────────────────┐   │
│   3. ORG-GOVERNANCE  │◄──┤
│  ─────────────────   │   │
│  • Organizations     │   │
│  • Tag Policies      │   │
│  • SCPs              │   │
└──────────────────────┘   │
         │                 │
         │ Enforces        │
         ▼                 │
┌──────────────────────┐   │
│ 4. APPREGISTRY       │◄──┤
│  ─────────────────   │   │
│  • Portfolio App     │   │
│  • System Apps       │   │
│    - webportal-dev   │   │
│    - webportal-stg   │   │
│    - webportal-prod  │   │
│  • Attribute Groups  │   │
└──────────────────────┘   │
         │                 │
         │                 │
         ▼                 │
┌──────────────────────┐   │
│ 5. CONFIG RECORDER   │◄──┤
│  ─────────────────   │   │
│  • Config Recorder   │   │
│  • Config Rules      │   │
│  • S3 Logs Bucket    │   │
└──────────────────────┘   │
         │                 │
         │ Scans           │
         ▼                 │
┌──────────────────────┐   │
│ 6. RESOURCE EXPLORER │◄──┤
│  ─────────────────   │   │
│  • Aggregator Index  │   │
│  • Default View      │   │
│  • Apps View         │   │
└──────────────────────┘   │
         │                 │
         │ Queries         │
         ▼                 │
┌──────────────────────┐   │
│ 7. TAG RECONCILER    │◄──┘
│  ─────────────────   │
│  • Lambda Function   │
│  • EventBridge       │
│    (every 6 hours)   │
└──────────────────────┘
         │
         │ Associates
         ▼
┌──────────────────────┐
│ 8. FINOPS (Optional) │
│  ─────────────────   │
│  • CloudTrail        │
│  • CUR → S3          │
│  • Glue Catalog      │
│  • Athena Queries    │
└──────────────────────┘
```

---

## 🔄 Data Flow

### 1️⃣ Tag Enforcement Flow

```
Developer creates resource
         │
         ▼
┌────────────────────┐
│  Tag Policy        │  ──→  Validates required tags:
│  (Organizations)   │       • Environment
└────────────────────┘       • System
         │                   • Owner
         │                   • awsApplication
         ▼
     ✅ Tags valid
         │
         ▼
┌────────────────────┐
│  Resource Created  │
│  with tags         │
└────────────────────┘
```

### 2️⃣ CMDB Auto-Discovery Flow

```
Resources with tags deployed
         │
         ▼
┌────────────────────┐
│  Config Recorder   │  ──→  Tracks all changes
└────────────────────┘
         │
         ▼
┌────────────────────┐
│ Resource Explorer  │  ──→  Indexes all resources
│  (every 24 hours)  │       Searchable by tags
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  EventBridge       │  ──→  Triggers every 6 hours
└────────────────────┘
         │
         ▼
┌────────────────────┐
│ Tag Reconciler     │  ──→  Query: "tag.key:awsApplication"
│    Lambda          │
└────────────────────┘
         │
         │ Groups by awsApplication value
         ▼
┌────────────────────┐
│  AppRegistry       │  ──→  Auto-associates resources
│  Applications      │       to correct application
└────────────────────┘
         │
         ▼
     CMDB Updated! ✅
```

### 3️⃣ CI/CD Authentication Flow

```
GitHub Actions Workflow triggered
         │
         ▼
┌────────────────────┐
│  GitHub OIDC       │  ──→  Request temporary credentials
│  Token             │
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  AWS IAM OIDC      │  ──→  Validates token
│  Provider          │       Checks repo, branch
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  AssumeRole        │  ──→  Returns temporary credentials
│  (dev/stg/prod)    │       Scoped to environment
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  Terraform Apply   │  ──→  Deploy infrastructure
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  State → S3        │  ──→  Locked via DynamoDB
│  + DynamoDB Lock   │       Encrypted with KMS
└────────────────────┘
```

### 4️⃣ Cost Analysis Flow

```
Resources deployed with tags
         │
         ▼
┌────────────────────┐
│  CloudTrail        │  ──→  Logs all API calls
│  (org trail)       │
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  Cost & Usage      │  ──→  Daily cost reports
│  Report (CUR)      │       with resource tags
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  S3 Bucket         │  ──→  Stores Parquet files
│  (CUR data)        │
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  Glue Crawler      │  ──→  Catalogs data
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  Athena / QuickSight │ → Query costs by:
│                    │     • Environment
│                    │     • System
│                    │     • Owner
│                    │     • awsApplication
└────────────────────┘
```

---

## 🏢 Multi-Environment Architecture

### Single Account with Tag-Based Separation

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS ACCOUNT (Single)                     │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │            FOUNDATION LAYER                        │   │
│  │  (Organizations, Config, AppRegistry, etc.)        │   │
│  └────────────────────────────────────────────────────┘   │
│                          │                                  │
│        ┌─────────────────┼─────────────────┐               │
│        │                 │                 │               │
│        ▼                 ▼                 ▼               │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐        │
│  │   DEV    │      │   STG    │      │   PROD   │        │
│  │ ──────── │      │ ──────── │      │ ──────── │        │
│  │ VPC:     │      │ VPC:     │      │ VPC:     │        │
│  │ dev-net  │      │ stg-net  │      │ prod-net │        │
│  │          │      │          │      │          │        │
│  │ Tags:    │      │ Tags:    │      │ Tags:    │        │
│  │ Env=dev  │      │ Env=stg  │      │ Env=prod │        │
│  │ System=  │      │ System=  │      │ System=  │        │
│  │ webportal│      │ webportal│      │ webportal│        │
│  │          │      │          │      │          │        │
│  │ AppReg:  │      │ AppReg:  │      │ AppReg:  │        │
│  │ webportal│      │ webportal│      │ webportal│        │
│  │   -dev   │      │   -stg   │      │   -prod  │        │
│  └──────────┘      └──────────┘      └──────────┘        │
│                                                             │
│  State Files (S3):                                         │
│  ├── dev/                                                  │
│  │   ├── network/terraform.tfstate                        │
│  │   └── apps/webportal/terraform.tfstate                 │
│  ├── stg/                                                  │
│  │   └── network/terraform.tfstate                        │
│  └── prod/                                                 │
│      ├── network/terraform.tfstate                        │
│      └── apps/webportal/terraform.tfstate                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Security Layers                         │
└─────────────────────────────────────────────────────────────┘

1️⃣  IAM OIDC + AssumeRole
    ┌──────────────────────────────────────────────┐
    │  GitHub Actions                              │
    │  ├── Repo: org/repo                          │
    │  └── Branch: main                            │
    └──────────────────┬───────────────────────────┘
                       │ OIDC Token
                       ▼
    ┌──────────────────────────────────────────────┐
    │  IAM OIDC Provider                           │
    │  Trust Policy:                               │
    │  - Repo match                                │
    │  - Branch match                              │
    └──────────────────┬───────────────────────────┘
                       │ AssumeRole
                       ▼
    ┌──────────────────────────────────────────────┐
    │  IAM Role (per environment)                  │
    │  ├── dev-terraform-deployer                  │
    │  ├── stg-terraform-deployer                  │
    │  └── prod-terraform-deployer                 │
    │                                              │
    │  Permissions scoped by tags:                 │
    │  - Can only manage resources with            │
    │    matching Environment tag                  │
    └──────────────────────────────────────────────┘

2️⃣  State Security
    ┌──────────────────────────────────────────────┐
    │  S3 Bucket (State)                           │
    │  ├── Versioning: Enabled                     │
    │  ├── Encryption: KMS (SSE-KMS)               │
    │  ├── Public Access: Blocked                  │
    │  └── MFA Delete: Recommended                 │
    └──────────────────────────────────────────────┘
    ┌──────────────────────────────────────────────┐
    │  DynamoDB Table (Lock)                       │
    │  ├── Encryption: KMS                         │
    │  └── Point-in-time Recovery: Enabled         │
    └──────────────────────────────────────────────┘
    ┌──────────────────────────────────────────────┐
    │  KMS Key                                     │
    │  ├── Rotation: Enabled (yearly)              │
    │  └── Key Policy: Scoped to roles             │
    └──────────────────────────────────────────────┘

3️⃣  Governance & Compliance
    ┌──────────────────────────────────────────────┐
    │  Tag Policies (Organizations)                │
    │  ├── Enforce required tags                   │
    │  └── Prevent tag deletion (SCP)              │
    └──────────────────────────────────────────────┘
    ┌──────────────────────────────────────────────┐
    │  AWS Config Rules                            │
    │  ├── Check required tags                     │
    │  ├── S3 public access prohibited             │
    │  └── Encrypted volumes                       │
    └──────────────────────────────────────────────┘
    ┌──────────────────────────────────────────────┐
    │  CloudTrail (Audit)                          │
    │  ├── Multi-region                            │
    │  ├── Log file validation                     │
    │  └── S3 + CloudWatch Logs                    │
    └──────────────────────────────────────────────┘
```

---

## 📊 Monitoring & Observability

```
┌─────────────────────────────────────────────────────────────┐
│                     Monitoring Stack                        │
└─────────────────────────────────────────────────────────────┘

📈 Metrics
   ┌──────────────────────────────────────────────┐
   │  CloudWatch Metrics                          │
   │  ├── Lambda: Tag Reconciler                  │
   │  │   ├── Invocations                         │
   │  │   ├── Errors                              │
   │  │   └── Duration                            │
   │  ├── Config: Compliance                      │
   │  │   ├── Compliant resources                 │
   │  │   └── Non-compliant resources             │
   │  └── Resource Explorer:                      │
   │      └── Indexed resources count             │
   └──────────────────────────────────────────────┘

📝 Logs
   ┌──────────────────────────────────────────────┐
   │  CloudWatch Logs                             │
   │  ├── /aws/lambda/tag-reconciler              │
   │  ├── /aws/config/*                           │
   │  └── CloudTrail logs                         │
   └──────────────────────────────────────────────┘

🔔 Alarms
   ┌──────────────────────────────────────────────┐
   │  CloudWatch Alarms                           │
   │  ├── Lambda errors > threshold               │
   │  ├── Config non-compliance detected          │
   │  └── State lock contention                   │
   └──────────────────────────────────────────────┘

💰 Cost Monitoring
   ┌──────────────────────────────────────────────┐
   │  Cost Explorer                               │
   │  ├── By Environment tag                      │
   │  ├── By System tag                           │
   │  └── By awsApplication tag                   │
   └──────────────────────────────────────────────┘
```

---

## 🎯 Summary

Foundation layer provides:

- ✅ **Centralized state management** (S3 + DynamoDB + KMS)
- ✅ **Secure CI/CD** (IAM OIDC, no long-term credentials)
- ✅ **Tag governance** (Organizations policies + Config rules)
- ✅ **CMDB automation** (AppRegistry + Resource Explorer + Lambda)
- ✅ **Cost visibility** (CUR + tagged resources)
- ✅ **Audit trail** (CloudTrail org trail)
- ✅ **Compliance checks** (Config rules)

All deployed **once** and shared across dev/stg/prod environments! 🚀
