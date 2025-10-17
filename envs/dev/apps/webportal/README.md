# WebPortal Application

## 📋 Overview

WebPortal là web application chính chạy trên **ECS Fargate** với **Application Load Balancer** và **Aurora MySQL Serverless v2**.

## 🏗️ Architecture

```
Internet
   │
   ▼
┌─────────┐
│   ALB   │ (HTTP/HTTPS)
└────┬────┘
     │
     ▼
┌──────────────────┐     ┌──────────────┐
│  ECS Fargate     │────▶│   Aurora     │
│  (Spot)          │     │   MySQL      │
│  0.25 vCPU       │     │  Serverless  │
│  0.5 GB RAM      │     │  (0.5-1 ACU) │
└──────────────────┘     └──────────────┘
     │
     ▼
┌──────────────────┐
│  CloudWatch      │
│  Logs + Alarms   │
└──────────────────┘
```

## 🎯 Components

| Component | Resource | Configuration |
|-----------|----------|---------------|
| **Compute** | ECS Fargate Spot | 0.25 vCPU, 0.5 GB RAM |
| **Load Balancer** | Application Load Balancer | Public-facing, HTTP |
| **Database** | Aurora MySQL Serverless v2 | 0.5-1 ACU, Auto-scaling |
| **Container Registry** | ECR | Private registry with image scanning |
| **Logging** | CloudWatch Logs | 7-day retention |
| **Monitoring** | CloudWatch Alarms | CPU, 5xx errors |
| **CMDB** | AppRegistry | `dev-webportal` |

## 🚀 Deployment

### Prerequisites

1. Platform Network deployed
2. Platform IAM & Secrets deployed
3. Docker image built and pushed to ECR

### Build & Push Docker Image

```bash
# Build Docker image
docker build -t webportal:latest .

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Tag image
docker tag webportal:latest \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/dev/webportal:latest

# Push to ECR
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/dev/webportal:latest
```

### Deploy Infrastructure

```bash
cd envs/dev/apps/webportal

# Initialize
terraform init

# Plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars

# Get ALB URL
terraform output alb_url
```

## 🧪 Testing

### Health Check

```bash
ALB_URL=$(terraform output -raw alb_url)
curl $ALB_URL/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "webportal",
  "timestamp": "2025-01-01T00:00:00Z"
}
```

### Load Testing

```bash
# Simple load test
ab -n 1000 -c 10 $ALB_URL/health

# Or using hey
hey -n 1000 -c 10 $ALB_URL/health
```

### Database Connection Test

```bash
# Connect to ECS task
aws ecs execute-command \
  --cluster dev-cluster \
  --task <TASK_ID> \
  --container webportal \
  --interactive \
  --command "/bin/bash"

# Inside container, test DB connection
mysql -h $DB_HOST -u admin -p webportal
```

## 📊 Monitoring

### CloudWatch Logs

```bash
# View ECS logs
aws logs tail /ecs/dev/webportal --follow

# Filter errors
aws logs tail /ecs/dev/webportal --follow --filter-pattern "ERROR"
```

### CloudWatch Metrics

```bash
# Check ECS CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=dev-webportal Name=ClusterName,Value=dev-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Check ALB requests
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/dev-webportal-alb/<ID> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Check Alarms

```bash
# List alarms
aws cloudwatch describe-alarms --alarm-name-prefix "dev-webportal"

# Get alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name dev-webportal-cpu-high \
  --max-records 10
```

## 🛠️ Operations

### Update ECS Service

```bash
# Update task definition (after new image push)
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-webportal \
  --force-new-deployment

# Watch deployment
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-webportal \
  --query 'services[0].events[:5]'
```

### Scale ECS Service

```bash
# Scale up
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-webportal \
  --desired-count 2

# Scale down
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-webportal \
  --desired-count 1
```

### Database Operations

```bash
# Check Aurora cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier dev-webportal-cluster

# Check current ACU usage
aws rds describe-db-clusters \
  --db-cluster-identifier dev-webportal-cluster \
  --query 'DBClusters[0].ServerlessV2ScalingConfiguration'

# Create snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier dev-webportal-snapshot-$(date +%Y%m%d) \
  --db-cluster-identifier dev-webportal-cluster
```

## 💰 Cost Optimization

### Current Configuration

- **ECS Fargate Spot**: ~$5-10/month (0.25 vCPU, 0.5 GB)
- **ALB**: ~$20/month
- **Aurora Serverless v2**: ~$40-80/month (0.5-1 ACU)
- **Total**: ~$65-110/month

### Auto-Stop (Save 60%)

```bash
# Stop ECS service
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-webportal \
  --desired-count 0

# Stop Aurora cluster
aws rds stop-db-cluster \
  --db-cluster-identifier dev-webportal-cluster
```

With auto-stop: ~$26-44/month

## 🔧 Troubleshooting

### ECS Tasks Not Starting

```bash
# Check task failures
aws ecs list-tasks \
  --cluster dev-cluster \
  --desired-status STOPPED \
  --query 'taskArns[:5]'

# Describe stopped task
aws ecs describe-tasks \
  --cluster dev-cluster \
  --tasks <TASK_ARN>
```

### ALB Health Checks Failing

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN>

# Test health endpoint locally
docker run -p 80:80 <IMAGE> &
curl http://localhost/health
```

### Database Connection Issues

```bash
# Check security group
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID>

# Test from ECS task
aws ecs execute-command \
  --cluster dev-cluster \
  --task <TASK_ID> \
  --container webportal \
  --interactive \
  --command "nc -zv $DB_HOST 3306"
```

## 📚 References

- [ECS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
