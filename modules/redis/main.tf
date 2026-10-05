locals {
  replication_group_id = "${var.name_prefix}-redis"
  ha                   = var.num_cache_clusters >= 2
  # ElastiCache names member clusters <replication_group_id>-001, -002
  cluster_ids = [
    for index in range(var.num_cache_clusters) :
    "${local.replication_group_id}-${format("%03d", index + 1)}"
  ]
}

resource "random_password" "auth" {
  length  = 32
  special = false
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = local.replication_group_id
  description          = var.description

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port

  num_cache_clusters = var.num_cache_clusters

  #Failover needs a replica; a single-node dev cluster runs without it
  automatic_failover_enabled = local.ha
  multi_az_enabled           = local.ha

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.auth.result

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.security_group_id]

  apply_immediately = true

  tags = {
    Name = local.replication_group_id
  }
}


# Connection info for the apps: endpoints in SSH, AUTH token in Secrets Manager

resource "aws_ssm_parameter" "primary_endpoint" {
  name  = "/${var.name_prefix}/redis-primary-endpoint"
  type  = "String"
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

resource "aws_ssm_parameter" "reader_endpoint" {
  name  = "/${var.name_prefix}/redis-reader-endpoint"
  type  = "String"
  value = aws_elasticache_replication_group.this.reader_endpoint_address
}

resource "aws_ssm_parameter" "port" {
  name  = "/${var.name_prefix}/redis-port"
  type  = "String"
  value = tostring(aws_elasticache_replication_group.this.port)
}

resource "aws_secretsmanager_secret" "auth" {
  name                    = "${var.name_prefix}/redis/auth-token"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "auth" {
  secret_id     = aws_secretsmanager_secret.auth.id
  secret_string = random_password.auth.result
}
