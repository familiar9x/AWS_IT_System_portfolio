variable "name" { type = string }
variable "username" { type = string }
variable "password" { type = string }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "source_sg_id" { type = string }

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "db" {
  name   = "${var.name}-rds-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [var.source_sg_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "this" {
  identifier                 = var.name
  engine                     = "sqlserver-se"
  instance_class             = "db.m6i.large"
  allocated_storage          = 50
  storage_type               = "gp3"
  multi_az                   = false
  username                   = var.username
  password                   = var.password
  db_subnet_group_name       = aws_db_subnet_group.this.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  backup_retention_period    = 7
  deletion_protection        = false
  publicly_accessible        = false
  auto_minor_version_upgrade = true
}

output "endpoint" { value = aws_db_instance.this.address }
output "sg_id" { value = aws_security_group.db.id }
