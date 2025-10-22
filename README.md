# CMDB — Full Project with AI Assistant (FE: S3+CloudFront, BE: ECS Fargate + RDS SQL Server + AI Lambda)

## 🤖 What you get
- **Terraform-only infra**: VPC, NAT, ALB (HTTPS), ECS Fargate (api + extsys1/2 + scheduled ingest), RDS SQL Server (private), ECR, Secrets Manager, CloudWatch.
- **FE static hosting**: S3 (private) + CloudFront (OAC). Route53 records for `app.<domain>` and `api.<domain>`.
- **Production-ready API**: Node.js Express API with proper error handling, database integration, health checks, and security middleware.
- **Mock external systems**: Two external services with realistic mock data for testing integrations.
- **Monitoring**: CloudWatch dashboards, alarms for CPU/Memory/Response time, and health monitoring.
- **🚀 AI Assistant**: Natural language querying with AWS Bedrock (Claude 3 Haiku), Lambda-based SQL generation, React chat interface.

---

## 🚀 Quick start

### Prerequisites
- AWS CLI configured
- Docker installed
- Terraform >= 1.6.0
- Domain name hosted in Route53
- ACM certificates created for your domain

### 1. Build & push images
```bash
# Build and tag images
### 1. Quick deployment (Recommended)
```bash
# Complete deployment with one command
./deploy.sh full-deploy prod

# Or step by step
./deploy.sh build prod      # Build all images (API + AI Lambda)
./deploy.sh deploy prod     # Deploy infrastructure
./deploy.sh frontend prod   # Build and upload React frontend
```

### 2. Manual deployment
```bash
# Build and tag images
cd backend/api-node
docker build -t cmdb-api:1.0.0 .

cd ../extsys1  
docker build -t cmdb-extsys1:1.0.0 .

cd ../extsys2
docker build -t cmdb-extsys2:1.0.0 .

# Build AI Lambda
cd ../../ai_lambda
docker build -t cmdb-ai-assistant:1.0.0 .

# Push to ECR (after terraform creates repos)
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com

docker tag cmdb-api:1.0.0 <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com/cmdb-api:1.0.0
docker push <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com/cmdb-api:1.0.0

docker tag cmdb-extsys1:1.0.0 <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com/cmdb-extsys1:1.0.0  
docker push <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com/cmdb-extsys1:1.0.0

docker tag cmdb-extsys2:1.0.0 <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com/cmdb-extsys2:1.0.0
docker push <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com/cmdb-extsys2:1.0.0

docker tag cmdb-ai-assistant:1.0.0 <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com/cmdb-ai-assistant:1.0.0
docker push <account_id>.dkr.ecr.ap-southeast-1.amazonaws.com/cmdb-ai-assistant:1.0.0
```

### 3. Deploy with Terraform
```bash
cd infra_terraform/envs/prod
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

### 4. Setup Terraform Backend (Recommended)
```bash
# Create S3 bucket and DynamoDB table for remote state
./deploy.sh bootstrap-backend

# After bootstrap, enable backend in infra_terraform/envs/prod/backend.tf
# Uncomment the backend "s3" block and update with your account ID

# Then migrate existing state (if any)
cd infra_terraform/envs/prod
terraform init -migrate-state
```

### 5. Setup Database Schema (Required for AI)
```bash
# Connect to your RDS instance and run:
sqlcmd -S <rds-endpoint> -U <username> -P <password> -d CMDB -i database/ai_schema.sql

# Or use SQL Server Management Studio to run the script
```

### 6. Test the deployment
- **Frontend with AI Chat**: `https://app.<base_domain>`
- **API Health**: `https://api.<base_domain>/health`
- **API Endpoints**: `https://api.<base_domain>/api/v1/ci`
- **AI Assistant**: `https://<ai-api-gateway-url>/prod/ask`
- **CloudWatch Dashboard**: Check terraform outputs for dashboard URL

### 7. Configure Frontend Environment
```bash
cd frontend
cp .env.example .env
# Edit .env with your API Gateway URL from Terraform outputs
```

> 💡 **AI Assistant Features**: Ask questions like "Thiết bị nào sắp hết hạn bảo hành?", "Chi phí bảo hành tháng này", "Thống kê thiết bị theo loại"

---

## 🤖 AI Assistant Features

### Natural Language Queries
- **Warranty expiration**: "Thiết bị nào sắp hết hạn bảo hành trong tháng này?"
- **Cost analysis**: "Tổng chi phí bảo hành theo quý"
- **Device statistics**: "Thống kê thiết bị theo loại"
- **Search devices**: "Tìm thiết bị WEB-SERVER"
- **Recent changes**: "Thay đổi gần đây trong hệ thống"
- **Expired warranties**: "Thiết bị nào đã hết hạn bảo hành?"

### Supported Intent Categories
| Intent | Description | Example Query |
|--------|-------------|---------------|
| `MA_EXPIRING` | Thiết bị sắp hết hạn | "Thiết bị hết hạn tháng này" |
| `MA_EXPIRED` | Thiết bị đã hết hạn | "Thiết bị đã hết hạn bảo hành" |
| `MA_COST_BY_MONTH` | Chi phí theo thời gian | "Chi phí bảo hành quý này" |
| `DEVICES_BY_TYPE` | Thống kê theo loại | "Thống kê server và switch" |
| `CHANGES_LAST_30D` | Thay đổi gần đây | "Thay đổi trong 30 ngày" |
| `DEVICE_SEARCH` | Tìm kiếm thiết bị | "Tìm laptop DEV" |

### AI Architecture
- **Frontend**: React chat interface with real-time responses
- **API Gateway**: HTTP API with CORS support
- **Lambda**: Python container with SQL Server ODBC driver
- **Bedrock**: Claude 3 Haiku for natural language understanding
- **Database**: SQL Server with optimized views and readonly user

---

## 🔧 Configuration Variables

### Required Variables in `terraform.tfvars`
| Variable | Description | Example |
|----------|-------------|---------|
| `account_id` | Your AWS account ID | `123456789012` |
| `region` | Primary region for resources | `ap-southeast-1` |
| `region_us_east_1` | Must be `us-east-1` for CloudFront | `us-east-1` |
| `base_domain` | Your domain (Route53 hosted) | `example.com` |
| `cloudfront_cert_arn` | ACM cert in us-east-1 for app subdomain | `arn:aws:acm:us-east-1:...` |
| `alb_cert_arn` | ACM cert in primary region for API | `arn:aws:acm:ap-southeast-1:...` |
| `db_username` | Database admin username | `cmdbadmin` |
| `db_password` | Database password (**use strong password**) | `YourSecurePassword123!` |
| `api_image_tag` | Docker tag for API service | `1.0.0` |
| `ext1_image_tag` | Docker tag for external system 1 | `1.0.0` |
| `ext2_image_tag` | Docker tag for external system 2 | `1.0.0` |

---

## 🏗️ Architecture Overview

### Infrastructure Components
- **VPC**: 2 public + 2 private subnets across AZs, NAT gateway
- **ALB**: HTTPS load balancer with SSL termination for `api.<domain>`
- **ECS Fargate**: Container orchestration for scalable services
  - API service (port 3000) - Main CMDB API
  - External System 1 (port 8001) - Server/Infrastructure data
  - External System 2 (port 8002) - Network equipment data
- **RDS SQL Server**: Private database with Multi-AZ option
- **Secrets Manager**: Secure storage for database credentials and API keys
- **ECR**: Container registry for Docker images
- **CloudFront + S3**: Static website hosting with OAC for `app.<domain>`
- **Route53**: DNS records for both subdomains
- **CloudWatch**: Comprehensive monitoring, dashboards, and alerting

### Security Features
- ✅ Private subnets for database and containers
- ✅ Security groups with least privilege access
- ✅ Secrets Manager for credential management
- ✅ HTTPS everywhere with ACM certificates
- ✅ Container security with non-root users
- ✅ VPC isolation and NAT gateway for outbound traffic

---

## 📊 API Endpoints

### Health & Monitoring
- `GET /health` - Service health check with database status
- `GET /api/v1/ci` - List configuration items (with filtering)
- `GET /api/v1/ci/:id` - Get specific configuration item
- `POST /api/v1/ci` - Create new configuration item
- `GET /api/v1/external/devices` - External systems integration status

### Sample API Usage
```bash
# Check API health
curl https://api.yourdomain.com/health

# Get all configuration items
curl https://api.yourdomain.com/api/v1/ci

# Filter by type
curl "https://api.yourdomain.com/api/v1/ci?type=server&status=running"

# Create new CI
curl -X POST https://api.yourdomain.com/api/v1/ci \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Web Server 01",
    "type": "server", 
    "environment": "production",
    "owner": "ops-team"
  }'
```

---

## 🔍 Monitoring & Alerting

### CloudWatch Dashboards
After deployment, check Terraform outputs for the dashboard URL, which includes:
- ECS service CPU and memory utilization
- ALB request count, response times, and error rates  
- Target health status
- Database connection metrics

### Default Alarms
- **High CPU**: >80% for 10 minutes
- **High Memory**: >85% for 10 minutes  
- **Unhealthy Targets**: Any unhealthy ALB targets
- **High Response Time**: >1 second average

### Log Groups
- `/ecs/cmdb-api` - Main API logs
- `/ecs/cmdb-extsys1` - External system 1 logs
- `/ecs/cmdb-extsys2` - External system 2 logs

---

## 🚀 Development & Deployment

### Local Development
```bash
# Run API locally
cd backend/api-node
cp .env.example .env
# Edit .env with local database settings
npm install
npm run dev

# Run external systems
cd ../extsys1 && npm start &
cd ../extsys2 && npm start &
```

### Production Deployment
1. **Update image tags** in `terraform.tfvars`
2. **Push new images** to ECR
3. **Apply Terraform changes**: `terraform apply`
4. **Monitor deployment** via CloudWatch dashboard

### Database Schema
The API automatically creates these tables:
- `ConfigurationItems` - Main CMDB inventory table

### Environment Variables (Container)
```bash
# Database
DB_HOST=<rds-endpoint>
DB_NAME=CMDB  
DB_USER=cmdbadmin
DB_PASS=<from-secrets-manager>

# External Systems
EXTSYS1_URL=http://extsys1:8001/devices
EXTSYS2_URL=http://extsys2:8002/devices

# Security  
ALLOWED_ORIGINS=https://app.yourdomain.com
NODE_ENV=production
```

---

## 🛠️ Customization

### Adding New Services
1. Create new container in `backend/` directory
2. Add ECR repository in `modules/ecr/main.tf`
3. Add service definition in `modules/services/main.tf`  
4. Update monitoring in `modules/monitoring/main.tf`

### Database Migrations
For schema changes, consider adding:
- Migration scripts in `backend/api-node/migrations/`
- Database backup before changes
- Blue-green deployment strategy

### Security Hardening
- Enable RDS encryption at rest
- Add WAF rules for ALB
- Implement API authentication (JWT)
- Enable VPC Flow Logs
- Add AWS Config for compliance

---

## 💰 Cost Optimization

### Development Environment
- Use `db.t3.micro` for RDS (free tier eligible)
- Reduce ECS CPU/memory allocations
- Disable Multi-AZ for RDS
- Use smaller ALB (Application Load Balancer)

### Production Scaling
- Enable Auto Scaling for ECS services
- Configure RDS Multi-AZ for high availability
- Add CloudFront caching rules
- Implement ECS capacity providers

---

## 🔧 Troubleshooting

### Common Issues
1. **Service won't start**: Check ECS service logs in CloudWatch
2. **Database connection**: Verify security group rules and Secrets Manager
3. **ALB health checks failing**: Ensure containers expose correct ports
4. **Domain not resolving**: Check Route53 hosted zone configuration

### Useful Commands
```bash
# Check ECS service status
aws ecs describe-services --cluster cmdb --services cmdb-api

# View container logs
aws logs tail /ecs/cmdb-api --follow

# Test database connectivity
aws rds describe-db-instances --db-instance-identifier cmdb-cmdb

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

---

## 📚 Next Steps

1. **Add Authentication**: Implement JWT or AWS Cognito
2. **API Documentation**: Add OpenAPI/Swagger documentation  
3. **CI/CD Pipeline**: GitHub Actions or AWS CodePipeline
4. **Backup Strategy**: Automated database backups and point-in-time recovery
5. **Multi-Environment**: Add staging environment configuration
6. **Performance Testing**: Load testing with realistic data volumes

---

## 🗂️ Terraform Backend

### Remote State Storage
The project supports remote state storage using S3 + DynamoDB for team collaboration:

- **S3 Bucket**: Stores Terraform state files with versioning and encryption
- **DynamoDB Table**: Provides state locking to prevent concurrent modifications
- **IAM Role**: Dedicated permissions for backend access

### Setup Remote Backend
```bash
# 1. Bootstrap backend infrastructure (run once)
./deploy.sh bootstrap-backend

# 2. Enable backend configuration
# Edit: infra_terraform/envs/prod/backend.tf
# Uncomment the backend "s3" block and update account ID

# 3. Migrate to remote state
cd infra_terraform/envs/prod
terraform init -migrate-state
```

### Backend Configuration
```hcl
terraform {
  backend "s3" {
    bucket         = "cmdb-terraform-state-ACCOUNT_ID-ap-southeast-1"
    key            = "cmdb/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cmdb-terraform-state-lock"
    encrypt        = true
  }
}
```

### Benefits
- **State Sharing**: Multiple team members can work on the same infrastructure
- **State Locking**: Prevents concurrent modifications and state corruption
- **State History**: S3 versioning provides rollback capabilities
- **Security**: Encrypted state storage with proper IAM permissions

---

## 📁 Project Structure

```
AWS_IT_System_portfolio/
├── README.md                    # Project documentation
├── deploy.sh                    # Automated deployment script
├── script_git_push.sh          # Git automation
│
├── backend/                     # Backend Services
│   ├── api-node/               # Main CMDB API (Node.js + Express)
│   │   ├── Dockerfile          # Container configuration
│   │   ├── package.json        # Dependencies
│   │   ├── index.js           # API server
│   │   └── .env.example       # Environment template
│   ├── extsys1/               # External System 1 (Server data)
│   └── extsys2/               # External System 2 (Network data)
│
├── ai_lambda/                  # AI Assistant
│   ├── Dockerfile             # Python Lambda container
│   ├── lambda_function.py     # AI processing logic
│   └── requirements.txt       # Python dependencies
│
├── frontend/                   # React Frontend
│   ├── src/                   # React components
│   ├── package.json          # Frontend dependencies
│   ├── vite.config.js        # Build configuration
│   └── .env.example          # Environment template
│
├── infra_terraform/           # Infrastructure as Code
│   ├── envs/                 # Environment-specific configs
│   │   ├── dev/             # Development environment
│   │   └── prod/            # Production environment
│   └── modules/             # Reusable Terraform modules
│       ├── vpc/             # VPC & networking
│       ├── ecs/             # Container orchestration
│       ├── rds-mssql/       # SQL Server database
│       ├── alb/             # Load balancer
│       ├── monitoring/      # CloudWatch dashboards & alarms
│       ├── ai-assistant/    # AI Lambda infrastructure
│       └── secrets/         # Secrets Manager
│
└── database/                  # Database Scripts
    └── ai_schema.sql         # CMDB schema & sample data
```

### Backend Services Overview

| Service | Technology | Port | Purpose |
|---------|------------|------|---------|
| **api-node** | Node.js + Express + SQL Server | 3000 | Main CMDB REST API |
| **extsys1** | Node.js + Express | 8001 | Mock server/infrastructure data |
| **extsys2** | Node.js + Express | 8002 | Mock network equipment data |
| **ai_lambda** | Python + AWS Bedrock | Lambda | Natural language query processing |

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Test changes locally
4. Submit pull request with detailed description

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

**⚠️ Security Note**: This is a starter template. For production use, implement proper authentication, input validation, and follow AWS security best practices.
