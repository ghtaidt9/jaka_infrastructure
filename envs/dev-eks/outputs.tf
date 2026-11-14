output "region" {
  description = "AWS region the stack is deployed in"
  value       = var.region
}

output "vpc_id" {
  description = "VPC of the cluster"
  value       = module.network.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Run this to point kubectl at the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

# MOVED TO shared
# output "ecr_repository_urls" {
#   description = "ECR repository urls"
#   value       = module.ecr.repository_urls
# }

output "db_endpoints" {
  description = "DB urls"
  value       = { for k, db in module.postgres : k => db.address }
}

output "db_admin_secret_arns" {
  description = "Secret arns of the db admin"
  value       = { for k, db in module.postgres : k => db.admin_secret_arn }
}

output "db_app_secret_arns" {
  description = "Secret arns of the db app"
  value       = { for k, db in module.postgres : k => db.app_secret_arn }
}

output "redis_primary_endpoint" {
  description = "Redis url"
  value       = module.redis.primary_endpoint
}

output "redis_auth_secret_arn" {
  description = "Redis auth secret"
  value       = module.redis.auth_secret_arn
}