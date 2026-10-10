output "region" {
  description = "AWS region the stack is deployed in"
  value       = module.stack.region
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = module.stack.alb_dns_name
}

output "asg_names" {
  description = "ASG name per service"
  value       = module.stack.asg_names
}

output "ecr_repository_urls" {
  description = "ECR repository URL per service"
  value       = module.stack.ecr_repository_urls
}

output "image_tag_parameters" {
  description = "SSM parameter holding the image tag each service's ASG boots"
  value       = module.stack.image_tag_parameters
}

output "db_endpoints" {
  description = "RDS endpoints per service"
  value       = module.stack.db_endpoints
}

output "redis_primary_endpoint" {
  description = "Primary endpoint of the shared replication group"
  value       = module.stack.redis_primary_endpoint
}

output "s3_bucket_name" {
  description = "Shared microservices bucket"
  value       = module.stack.s3_bucket_name
}

output "app_log_group_names" {
  description = "CloudWatch log group per service"
  value       = module.stack.app_log_group_names
}

output "cloudwatch_dashboard_url" {
  description = "Console URL of the overview dashboard"
  value       = module.stack.cloudwatch_dashboard_url
}

output "ssm_caller_username" {
  description = "IAM user allowed to start SSM sessions"
  value       = module.stack.ssm_caller_username
}
