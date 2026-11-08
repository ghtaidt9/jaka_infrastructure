locals {
  project     = "jaka-mod"
  environment = "dev-eks"
  name_prefix = "${local.project}-${local.environment}"
  services    = toset(["order-service", "payment-service", "inventory-service", "notification-service"])
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
