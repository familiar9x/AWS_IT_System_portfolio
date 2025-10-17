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
│                  ENVIRONMENT LAYERS (Dev/Stg/Prod)               │
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
        └─→ awsApplication = "webportal-dev"

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
              ├─→ Dev Role (for dev branch)
              ├─→ Stg Role (for staging branch)
              └─→ Prod Role (for main branch)
                       │
                       └─→ Terraform operations
                                │
                                └─→ State encrypted (KMS)
                                     └─→ S3 (versioned)
                                     └─→ DynamoDB (locked)
```

## 📈 Scalability

- **Foundation**: 1 deployment cho toàn org
- **Environments**: Scale theo env (dev/stg/prod/...)
- **Applications**: Scale theo app trong mỗi env
- **Resources**: Unlimited, tracked by tags

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
