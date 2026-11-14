locals {
  project     = "jaka-mod"
  environment = "dev-eks"
  name_prefix = "${local.project}-${local.environment}"

  apps = {
    order        = { db_name = "orderdb" }
    payment      = { db_name = "paymentdb" }
    inventory    = { db_name = "inventorydb" }
    notification = { db_name = "notificationdb" }
  }

  # tên ServiceAccount = tên Helm release = "<key>-service"
  services = toset([for k in keys(local.apps) : "${k}-service"])
}

# VPC riêng cho EKS - không dùng chung với envs/dev
module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.32.0/20", "10.0.48.0/20"] # /20: mỗi Pod ăn 1 IP thật
  single_nat_gateway   = true

  # Để AWS Load Balancer Controller biết subnet nào đặt LB
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

module "eks" {
  source = "../../modules/eks"

  name_prefix        = local.name_prefix
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  node_instance_type = "t3.medium"
  node_min           = 2
  node_max           = 4
}


module "security" {
  source = "../../modules/security"

  name_prefix            = local.name_prefix
  create_ssm_caller_user = false
}

module "storage" {
  source = "../../modules/storage"

  name_prefix     = local.name_prefix
  tiered_prefixes = [for k in keys(local.apps) : "${k}s"]
  force_destroy   = true
}

# MOVED TO shared
# module "ecr" {
#   source = "../../modules/ecr"

#   services    = toset(keys(local.apps))
#   name_prefix = local.name_prefix
# }

module "redis" {
  source = "../../modules/redis"

  name_prefix                    = local.name_prefix
  private_subnet_ids             = module.network.private_subnet_ids
  security_group_id              = module.network.redis_sg_id
  kms_key_arn                    = module.security.kms_key_arn
  num_cache_clusters             = 1
  secret_recovery_window_in_days = 0
}

module "postgres" {
  source   = "../../modules/postgres"
  for_each = local.apps

  name_prefix    = local.name_prefix
  service        = each.key
  db_name        = each.value.db_name
  admin_username = "${each.key}_admin"
  app_username   = "${each.key}_user"

  private_subnet_ids = module.network.private_subnet_ids
  security_group_id  = module.network.rds_sg_id
  kms_key_id         = module.security.kms_key_id
  kms_key_arn        = module.security.kms_key_arn

  multi_az                       = false
  skip_final_snapshot            = true
  deletion_protection            = false
  secret_recovery_window_in_days = 0
}
