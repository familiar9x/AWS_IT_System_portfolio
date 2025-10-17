# Backoffice Application

## 📋 Overview

Backoffice là serverless application chạy trên **AWS Lambda (Arm64)** với **API Gateway HTTP API** và **DynamoDB** cho data storage.

## 🏗️ Architecture

```
Internet
   │
   ▼
┌──────────────┐
│ API Gateway  │ (HTTP API)
│   (REST)     │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│   Lambda     │────▶│  DynamoDB    │
│   (Arm64)    │     │ (On-Demand)  │
│  Python 3.11 │     │              │
└──────────────┘     └──────────────┘
       │
       ▼
┌──────────────┐
│  CloudWatch  │
│ Logs + X-Ray │
└──────────────┘
```

## 🎯 Components

| Component | Resource | Configuration |
|-----------|----------|---------------|
| **Compute** | Lambda (Arm64) | Python 3.11, 256 MB, 30s timeout |
| **API** | API Gateway HTTP API | Public REST API with CORS |
| **Database** | DynamoDB | Pay-per-request, GSI on status |
| **Storage** | S3 | Lambda artifacts bucket |
| **Logging** | CloudWatch Logs | 7-day retention |
| **Tracing** | X-Ray | Active tracing (5% sampling) |
| **Monitoring** | CloudWatch Alarms | Errors, throttles, 5xx |
| **CMDB** | AppRegistry | `backoffice-dev` |

## 🚀 Deployment

### Deploy Infrastructure

```bash
cd envs/dev/apps/backoffice

# Initialize
terraform init

# Plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars

# Get API endpoint
terraform output api_endpoint
```

## 🧪 Testing

### Health Check

```bash
API_URL=$(terraform output -raw api_endpoint)
curl $API_URL/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "backoffice"
}
```

### Create Item

```bash
curl -X POST $API_URL/items \
  -H "Content-Type: application/json" \
  -d '{
    "id": "item-001",
    "status": "pending",
    "description": "Test item"
  }'
```

### Get All Items

```bash
curl $API_URL/items
```

### Get Single Item

```bash
curl $API_URL/items/item-001
```

### Load Testing

```bash
# Simple load test
hey -n 1000 -c 10 -m GET $API_URL/health

# POST test
hey -n 100 -c 5 -m POST \
  -H "Content-Type: application/json" \
  -d '{"id":"test","status":"active"}' \
  $API_URL/items
```

## 📊 Monitoring

### CloudWatch Logs

```bash
# View Lambda logs
aws logs tail /aws/lambda/dev-backoffice-api --follow

# View API Gateway logs
aws logs tail /aws/apigateway/dev-backoffice --follow

# Filter errors
aws logs tail /aws/lambda/dev-backoffice-api --follow \
  --filter-pattern "ERROR"
```

### Lambda Metrics

```bash
# Invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=dev-backoffice-api \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Duration
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=dev-backoffice-api \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=dev-backoffice-api \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### X-Ray Traces

```bash
# Get trace summaries
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)

# Get specific trace
aws xray batch-get-traces --trace-ids <TRACE_ID>
```

### DynamoDB Metrics

```bash
# Read/Write capacity
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=dev-backoffice-data \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Item count
aws dynamodb describe-table \
  --table-name dev-backoffice-data \
  --query 'Table.ItemCount'
```

## 🛠️ Operations

### Update Lambda Function

```bash
# Update code
cd lambda
zip -r ../function.zip .

# Update function
aws lambda update-function-code \
  --function-name dev-backoffice-api \
  --zip-file fileb://../function.zip

# Or via Terraform
terraform apply -var-file=terraform.tfvars
```

### Update Environment Variables

```bash
# Via CLI
aws lambda update-function-configuration \
  --function-name dev-backoffice-api \
  --environment Variables="{DYNAMODB_TABLE=dev-backoffice-data,LOG_LEVEL=INFO}"

# Or update in Terraform and apply
```

### Invoke Lambda Directly

```bash
# Test invocation
aws lambda invoke \
  --function-name dev-backoffice-api \
  --payload '{"httpMethod":"GET","path":"/health"}' \
  response.json

cat response.json
```

### DynamoDB Operations

```bash
# Scan table
aws dynamodb scan --table-name dev-backoffice-data --limit 10

# Query by status (using GSI)
aws dynamodb query \
  --table-name dev-backoffice-data \
  --index-name StatusIndex \
  --key-condition-expression "#status = :status" \
  --expression-attribute-names '{"#status":"status"}' \
  --expression-attribute-values '{":status":{"S":"pending"}}'

# Get item
aws dynamodb get-item \
  --table-name dev-backoffice-data \
  --key '{"id":{"S":"item-001"},"timestamp":{"N":"0"}}'

# Delete item
aws dynamodb delete-item \
  --table-name dev-backoffice-data \
  --key '{"id":{"S":"item-001"},"timestamp":{"N":"0"}}'
```

### Backup & Restore

```bash
# Create on-demand backup
aws dynamodb create-backup \
  --table-name dev-backoffice-data \
  --backup-name dev-backoffice-backup-$(date +%Y%m%d)

# List backups
aws dynamodb list-backups --table-name dev-backoffice-data

# Restore from backup
aws dynamodb restore-table-from-backup \
  --target-table-name dev-backoffice-data-restored \
  --backup-arn <BACKUP_ARN>
```

## 💰 Cost Optimization

### Current Configuration (Estimated)

- **Lambda**: ~$1-2/month (1M requests, 256 MB, Arm64)
- **API Gateway**: ~$1/month (1M requests)
- **DynamoDB**: ~$1-5/month (on-demand, low volume)
- **S3**: <$1/month (minimal storage)
- **CloudWatch**: ~$1/month (logs)
- **Total**: ~$4-9/month

### Optimization Tips

1. **Use Arm64** (already enabled) - 20% cheaper
2. **Right-size memory** - Monitor and adjust if needed
3. **DynamoDB on-demand** - No idle costs
4. **Short log retention** - 7 days in dev
5. **X-Ray sampling** - 5% only (not 100%)

## 🔧 Troubleshooting

### Lambda Errors

```bash
# Get recent errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/dev-backoffice-api \
  --filter-pattern "ERROR" \
  --start-time $(($(date +%s) - 3600))000

# Check function configuration
aws lambda get-function-configuration \
  --function-name dev-backoffice-api
```

### API Gateway Issues

```bash
# Check API configuration
aws apigatewayv2 get-api --api-id <API_ID>

# Test integration
aws apigatewayv2 get-integration \
  --api-id <API_ID> \
  --integration-id <INTEGRATION_ID>

# Check routes
aws apigatewayv2 get-routes --api-id <API_ID>
```

### DynamoDB Access Issues

```bash
# Check IAM role permissions
aws iam get-role-policy \
  --role-name <LAMBDA_ROLE> \
  --policy-name dev-backoffice-lambda-dynamodb

# Test DynamoDB access from Lambda
aws lambda invoke \
  --function-name dev-backoffice-api \
  --payload '{"httpMethod":"GET","path":"/items"}' \
  response.json
```

### X-Ray Tracing Not Working

```bash
# Check Lambda configuration
aws lambda get-function-configuration \
  --function-name dev-backoffice-api \
  --query 'TracingConfig'

# Check X-Ray service map
aws xray get-service-graph \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)
```

## 🎓 Best Practices

### ✅ DO
- Use Arm64 for cost savings
- Enable X-Ray for debugging
- Use DynamoDB on-demand in dev
- Set appropriate timeouts
- Use CloudWatch Logs Insights for analysis
- Monitor Lambda cold starts

### ❌ DON'T
- Don't use provisioned concurrency in dev
- Don't keep large log retention
- Don't sample 100% with X-Ray
- Don't over-provision memory

## 📚 References

- [Lambda Arm64](https://aws.amazon.com/blogs/compute/migrating-aws-lambda-functions-to-arm-based-aws-graviton2-processors/)
- [API Gateway HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [DynamoDB On-Demand](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadWriteCapacityMode.html#HowItWorks.OnDemand)
- [X-Ray Tracing](https://docs.aws.amazon.com/lambda/latest/dg/services-xray.html)
