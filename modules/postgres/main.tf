locals {
  identifier = "${var.name_prefix}-${var.service}-db"

  parameter_group_family = "postgres${split(".", var.engine_version)[0]}"
}

# Network + parameters
resource "aws_db_subnet_group" "this" {
  name       = "${local.identifier}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${local.identifier}-subnet-group"
  }
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-${var.service}-pg"
  family = local.parameter_group_family

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/${local.identifier}/postgresql"
  retention_in_days = var.log_retention_days
}

# RDS instance. The admin password is RDS-managed (Secrets Manager + KMS)
resource "aws_db_instance" "this" {
  identifier        = local.identifier
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name                       = var.db_name
  username                      = var.admin_username
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_id
  apply_immediately             = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  multi_az                  = var.multi_az
  backup_retention_period   = var.backup_retention_period
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${local.identifier}-final-snapshot"
  deletion_protection       = var.deletion_protection
  storage_encrypted         = true

  parameter_group_name = aws_db_parameter_group.this.name

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  depends_on = [aws_cloudwatch_log_group.postgresql]

  tags = {
    Name = local.identifier
  }
}

resource "aws_secretsmanager_secret_rotation" "admin" {
  secret_id          = aws_db_instance.this.master_user_secret[0].secret_arn
  rotate_immediately = false

  rotation_rules {
    schedule_expression = "rate(${var.admin_secret_rotation_days} days)"
  }
}

# App login (e.g. order_user). The role itself is created in Postgres by the instance bootstrap script, which reads this secret
resource "random_password" "app" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.name_prefix}/${var.service}-db/app-credentials"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    engine   = "postgres"
    username = var.app_username
    password = random_password.app.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = aws_db_instance.this.db_name
  })
}

# Non-secret JDBC URL for the app (read at boot)
resource "aws_ssm_parameter" "db_url" {
  name  = "/${var.name_prefix}/${var.service}-db-url"
  type  = "String"
  value = "jdbc:postgresql://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${aws_db_instance.this.db_name}?sslmode=require"
}
