variable "name" { type = string }
variable "db_password" { type = string }

# Database password secret
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}/dbpass"
  description             = "Database password for ${var.name} CMDB"
  recovery_window_in_days = 7
  
  tags = {
    Name        = "${var.name}-db-password"
    Environment = "production"
    Service     = "cmdb"
  }
}

resource "aws_secretsmanager_secret_version" "dbv" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    password = var.db_password
    username = "cmdbadmin"
  })
}

# API keys secret for external integrations
resource "aws_secretsmanager_secret" "api_keys" {
  name                    = "${var.name}/api-keys"
  description             = "API keys for external system integrations"
  recovery_window_in_days = 7
  
  tags = {
    Name        = "${var.name}-api-keys"
    Environment = "production"
    Service     = "cmdb"
  }
}

resource "aws_secretsmanager_secret_version" "api_keys_version" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    extsys1_api_key = "placeholder-key-1"
    extsys2_api_key = "placeholder-key-2"
    jwt_secret      = "your-jwt-secret-key"
  })
}

# Output both secrets
output "db_secret_arn" { 
  value = aws_secretsmanager_secret.db.arn 
  description = "ARN of the database password secret"
}

output "api_keys_secret_arn" { 
  value = aws_secretsmanager_secret.api_keys.arn 
  description = "ARN of the API keys secret"
}
