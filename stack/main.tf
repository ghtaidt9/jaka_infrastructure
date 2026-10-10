data "aws_region" "current" {}

locals {
  name_prefix       = "${var.project}-${var.environment}"
  metrics_namespace = "Microservices/App"

  container_ports = [for s in values(var.services) : s.container_port]
}

module "network" {
  source = "../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  redis_port           = 6379

  app_port_range = {
    from = min(local.container_ports...)
    to   = max(local.container_ports...)
  }
}

module "security" {
  source = "../modules/security"

  name_prefix = local.name_prefix
}

module "storage" {
  source = "../modules/storage"

  name_prefix     = local.name_prefix
  tiered_prefixes = [for k in keys(var.services) : "${k}s"]
  force_destroy   = var.s3_force_destroy
}

module "alb" {
  source = "../modules/alb"

  name_prefix       = local.name_prefix
  public_subnet_ids = module.network.public_subnet_ids
  security_group_id = module.network.alb_sg_id
}

module "redis" {
  source = "../modules/redis"

  name_prefix                    = local.name_prefix
  private_subnet_ids             = module.network.private_subnet_ids
  security_group_id              = module.network.redis_sg_id
  kms_key_arn                    = module.security.kms_key_arn
  engine_version                 = var.redis.engine_version
  node_type                      = var.redis.node_type
  num_cache_clusters             = var.redis.num_cache_clusters
  secret_recovery_window_in_days = var.secret_recovery_window_in_days
}

module "postgres" {
  source   = "../modules/postgres"
  for_each = var.services

  name_prefix    = local.name_prefix
  service        = each.key
  db_name        = each.value.db_name
  admin_username = "${each.key}_admin"
  app_username   = "${each.key}_user"

  private_subnet_ids = module.network.private_subnet_ids
  security_group_id  = module.network.rds_sg_id
  kms_key_id         = module.security.kms_key_id
  kms_key_arn        = module.security.kms_key_arn

  engine_version                 = var.postgres.engine_version
  instance_class                 = var.postgres.instance_class
  allocated_storage              = var.postgres.allocated_storage
  multi_az                       = var.postgres.multi_az
  backup_retention_period        = var.postgres.backup_retention_period
  skip_final_snapshot            = var.postgres.skip_final_snapshot
  deletion_protection            = var.postgres.deletion_protection
  log_retention_days             = var.log_retention_days
  secret_recovery_window_in_days = var.secret_recovery_window_in_days
}

module "service" {
  source = "../modules/service"

  for_each = var.services

  name_prefix = local.name_prefix
  environment = var.environment
  service     = each.key

  container_port         = each.value.container_port
  health_check_path      = "/api/${each.key}s/actuator/health"
  path_patterns          = ["/api/${each.key}s", "/api/${each.key}s/*"]
  listener_arn           = module.alb.http_listener_arn
  listener_rule_priority = each.value.listener_rule_priority

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  security_group_ids = [module.network.ec2_sg_id]
  instance_type      = var.instance_type
  ami_id             = var.ami_id

  asg_min_size         = var.asg.min_size
  asg_max_size         = var.asg.max_size
  asg_desired_capacity = var.asg.desired_capacity
  asg_target_cpu       = var.asg.target_cpu

  image_tag = var.image_tag

  database = {
    host               = module.postgres[each.key].address
    port               = module.postgres[each.key].port
    name               = module.postgres[each.key].db_name
    admin_username     = module.postgres[each.key].admin_username
    admin_secret_arn   = module.postgres[each.key].admin_secret_arn
    app_username       = module.postgres[each.key].app_username
    app_secret_arn     = module.postgres[each.key].app_secret_arn
    url_parameter_name = module.postgres[each.key].db_url_parameter_name
  }

  redis = {
    primary_endpoint_parameter_name = module.redis.primary_endpoint_parameter_name
    port_parameter_name             = module.redis.port_parameter_name
    auth_secret_arn                 = module.redis.auth_secret_arn
    database_index                  = each.value.redis_database_index
  }

  kms_key_arn        = module.security.kms_key_arn
  s3_bucket_arn      = module.storage.bucket_arn
  metrics_namespace  = local.metrics_namespace
  log_retention_days = var.log_retention_days
}

module "observability" {
  source = "../modules/observability"

  name_prefix       = local.name_prefix
  environment       = var.environment
  alarm_email       = var.alarm_email
  metrics_namespace = local.metrics_namespace
  thresholds        = var.alarm_thresholds

  services = {
    for k, s in module.service : k => {
      container_name          = s.container_name
      asg_name                = s.asg_name
      target_group_arn_suffix = s.target_group_arn_suffix
      log_group_name          = s.log_group_name
    }
  }

  databases         = { for k, db in module.postgres : k => db.identifier }
  redis_cluster_ids = module.redis.cluster_ids
  alb_arn_suffix    = module.alb.arn_suffix
}
