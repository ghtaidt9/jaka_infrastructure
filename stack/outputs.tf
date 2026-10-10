output "name_prefix" {
  description = "Prefix of every resource name"
  value       = local.name_prefix
}

output "region" {
  description = "AWS region the stack is deployed in"
  value       = data.aws_region.current.name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = module.alb.dns_name
}

output "asg_names" {
  description = "ASG name per service"
  value       = { for k, s in module.service : k => s.asg_name }
}

output "ecr_repository_urls" {
  description = "ECR repository URL per service"
  value       = { for k, s in module.service : k => s.ecr_repository_url }
}

output "image_tag_parameters" {
  description = "SSM parameter holding the image tag each service's ASG boots"
  value       = { for k, s in module.service : k => s.image_tag_parameter_name }
}

output "app_log_group_names" {
  description = "CloudWatch log group per service"
  value       = { for k, s in module.service : k => s.log_group_name }
}

output "db_endpoints" {
  description = "RDS endpoint per service"
  value       = { for k, db in module.postgres : k => db.endpoint }
}

output "redis_primary_endpoint" {
  description = "Primary endpoint of the shared Redis replication group"
  value       = module.redis.primary_endpoint
}

output "redis_reader_endpoint" {
  description = "Reader endpoint of the shared Redis replication group"
  value       = module.redis.reader_endpoint
}

output "s3_bucket_name" {
  description = "Shared microservices bucket (<service>s/ prefixes)"
  value       = module.storage.bucket_name
}

output "alarms_sns_topic_arn" {
  description = "SNS topic receiving every alarm and RDS event"
  value       = module.observability.alarms_topic_arn
}

output "cloudwatch_dashboard_url" {
  description = "Console URL of the overview dashboard"
  value       = module.observability.dashboard_url
}

output "ssm_caller_username" {
  description = "IAM user allowed to start SSM sessions"
  value       = module.security.ssm_caller_username
}
