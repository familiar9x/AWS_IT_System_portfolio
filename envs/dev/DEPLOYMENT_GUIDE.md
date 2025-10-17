# Dev Environment - Deployment Guide

## 📋 Prerequisites

1. ✅ Foundation layer deployed
2. ✅ AppRegistry applications created:
   - `webportal-dev`
   - `api-service-dev`
3. ✅ Backend S3 bucket configured
4. ✅ IAM OIDC roles set up for CI/CD

## 🚀 Deployment Steps

### Step 1: Deploy Platform - Network Stack

```bash
cd envs/dev/platform/network-stack

# Initialize
terraform init -backend-config=backend.tf

# Review plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars

# Save outputs
terraform output -json > network-outputs.json
```

**Outputs:**
- VPC ID
- Subnet IDs (public, private, database)
- Security Group IDs
- NAT Gateway ID

### Step 2: Deploy Platform - IAM & Secrets

```bash
cd ../iam-secrets

# Initialize
terraform init -backend-config=backend.tf

# Apply
terraform apply -var-file=terraform.tfvars

# Save outputs
terraform output -json > iam-outputs.json
```

**Outputs:**
- ECS Task Execution Role ARN
- ECS Task Role ARN
- Lambda Execution Role ARN
- Secrets Manager ARNs

### Step 3: Deploy Application - WebPortal

```bash
cd ../../apps/webportal/app-stack

# Get network outputs
export VPC_ID=$(jq -r '.vpc_id.value' ../../../platform/network-stack/network-outputs.json)
export PRIVATE_SUBNETS=$(jq -r '.private_subnet_ids.value | join(",")' ../../../platform/network-stack/network-outputs.json)

# Initialize
terraform init -backend-config=backend.tf

# Apply with network info
terraform apply \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=$PRIVATE_SUBNETS"

# Test endpoint
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS
```

### Step 4: Deploy Application - API Service

```bash
cd ../../api-service/app-stack

terraform init -backend-config=backend.tf
terraform apply

# Test API
API_URL=$(terraform output -raw api_url)
curl $API_URL/health
```

### Step 5: Deploy Config Recorder

```bash
cd ../../../config-recorder

terraform init -backend-config=backend.tf
terraform apply

# Verify Config status
aws configservice describe-configuration-recorder-status
```

### Step 6: Deploy Observability

```bash
cd ../observability

terraform init -backend-config=backend.tf
terraform apply

# Check CloudWatch dashboards
aws cloudwatch list-dashboards
```

## ✅ Verification

### 1. Verify Network Connectivity

```bash
# Check VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=dev-network"

# Check NAT Gateway
aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=dev-nat"

# Check Flow Logs
aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/dev"
```

### 2. Verify Application Deployment

```bash
# Check ECS services
aws ecs list-services --cluster dev-cluster

# Check ALB
aws elbv2 describe-load-balancers --names webportal-dev-alb

# Check target health
aws elbv2 describe-target-health --target-group-arn <TG_ARN>
```

### 3. Verify Tagging

```bash
# Query Resource Explorer
aws resource-explorer-2 search \
  --query-string "tag:Environment=dev tag:System=webportal"

# Verify AppRegistry association
aws servicecatalog-appregistry list-associated-resources \
  --application webportal-dev
```

### 4. Verify Secrets

```bash
# List secrets
aws secretsmanager list-secrets \
  --filters Key=name,Values=dev/

# Get secret value (test only)
aws secretsmanager get-secret-value \
  --secret-id dev/webportal/db-credentials
```

## 🧪 Testing

### Test Application Endpoints

```bash
# WebPortal
curl -v http://webportal-dev-alb-xxxxx.us-east-1.elb.amazonaws.com

# API Service
curl -v https://xxxxx.execute-api.us-east-1.amazonaws.com/dev/health
```

### Test Database Connectivity

```bash
# From ECS task
aws ecs execute-command \
  --cluster dev-cluster \
  --task <task-id> \
  --container webportal \
  --interactive \
  --command "/bin/bash"

# Inside container
psql -h $DB_HOST -U $DB_USER -d $DB_NAME
```

### Test Lambda Functions

```bash
# Invoke Lambda
aws lambda invoke \
  --function-name api-processor-dev \
  --payload '{"test": "data"}' \
  response.json

cat response.json
```

## 📊 Monitoring

### CloudWatch Logs

```bash
# View application logs
aws logs tail /aws/ecs/webportal-dev --follow

# View Lambda logs
aws logs tail /aws/lambda/api-processor-dev --follow

# View VPC flow logs
aws logs tail /aws/vpc/dev-flow-logs --follow
```

### CloudWatch Metrics

```bash
# ECS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=webportal-dev \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average

# ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/webportal-dev-alb/xxxxx \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

## 🛠️ Troubleshooting

### Issue: ECS tasks not starting

```bash
# Check task definition
aws ecs describe-task-definition --task-definition webportal-dev

# Check service events
aws ecs describe-services \
  --cluster dev-cluster \
  --services webportal-dev \
  --query 'services[0].events[:5]'

# Check CloudWatch logs
aws logs tail /aws/ecs/webportal-dev --since 1h
```

### Issue: ALB health checks failing

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN>

# Check security group rules
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=<SG_ID>"

# Test from bastion
curl -v http://<PRIVATE_IP>:<PORT>/health
```

### Issue: RDS connection timeout

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier webportal-dev-db

# Check security group
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID>

# Test from ECS task
aws ecs execute-command --cluster dev-cluster --task <task-id> \
  --container webportal --interactive \
  --command "nc -zv $DB_HOST 5432"
```

### Issue: Secrets not accessible

```bash
# Check IAM role permissions
aws iam get-role-policy \
  --role-name dev-ecs-task-role \
  --policy-name secrets-access

# Check secret exists
aws secretsmanager describe-secret \
  --secret-id dev/webportal/db-credentials

# Check KMS key permissions
aws kms describe-key --key-id alias/terraform-state
```

## 🔄 Update Workflow

### Update Application Code

```bash
# Build new image
docker build -t webportal:v2 .

# Push to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_URL>
docker tag webportal:v2 <ECR_URL>/webportal:v2
docker push <ECR_URL>/webportal:v2

# Update ECS service
aws ecs update-service \
  --cluster dev-cluster \
  --service webportal-dev \
  --force-new-deployment
```

### Update Infrastructure

```bash
# Pull latest code
git pull origin develop

# Plan changes
cd envs/dev/apps/webportal/app-stack
terraform plan

# Apply if OK
terraform apply

# Verify deployment
terraform output alb_dns_name
```

## 💰 Cost Optimization

### Check Current Costs

```bash
# Get cost by tag
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Environment \
  --filter '{"Tags": {"Key": "Environment", "Values": ["dev"]}}'
```

### Enable Auto-Stop

```bash
# Stop ECS service after hours
aws ecs update-service \
  --cluster dev-cluster \
  --service webportal-dev \
  --desired-count 0

# Stop RDS instance
aws rds stop-db-instance \
  --db-instance-identifier webportal-dev-db
```

### Use Spot Instances

```bash
# Update ECS service to use Fargate Spot
aws ecs update-service \
  --cluster dev-cluster \
  --service webportal-dev \
  --capacity-provider-strategy \
    capacityProvider=FARGATE_SPOT,weight=1
```

## 🗑️ Cleanup

### Delete Application Stacks

```bash
# Delete in reverse order
cd envs/dev/observability
terraform destroy -auto-approve

cd ../config-recorder
terraform destroy -auto-approve

cd ../apps/api-service/app-stack
terraform destroy -auto-approve

cd ../../webportal/app-stack
terraform destroy -auto-approve
```

### Delete Platform

```bash
cd ../../../platform/iam-secrets
terraform destroy -auto-approve

cd ../network-stack
terraform destroy -auto-approve
```

### Verify Cleanup

```bash
# Check for remaining resources
aws resource-explorer-2 search --query-string "tag:Environment=dev"

# Should return empty
```

## 📚 References

- [Foundation Layer](../../../foundation/README.md)
- [Network Stack Details](./platform/network-stack/README.md)
- [Application Modules](../../../modules/README.md)
- [Terraform Best Practices](../../../terraform_best_practice.md)
