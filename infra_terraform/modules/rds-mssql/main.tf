variable "db_name" { type = string }
variable "username" { type = string }
variable "password" { type = string }
variable "subnet_ids" { type = list(string) }
variable "vpc_security_group_ids" { type = list(string) }

resource "aws_db_subnet_group" "this" {
  name       = "${var.db_name}-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "this" {
  identifier              = var.db_name
  engine                  = "sqlserver-se"
  instance_class          = "db.m6i.large"
  allocated_storage       = 100
  storage_type            = "gp3"
  multi_az                = true
  username                = var.username
  password                = var.password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = var.vpc_security_group_ids
  backup_retention_period = 7
  deletion_protection     = false
  publicly_accessible     = false
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
}

output "endpoint" { value = aws_db_instance.this.address }
