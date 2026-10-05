output "primary_endpoint" {
  description = "Primary (read/write) endpoint"
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Reader endpoint"
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.this.port
}

output "cluster_ids" {
  description = "Member cluster IDs (CacheClusterId dimension), known at plan time"
  value       = local.cluster_ids
}

output "primary_endpoint_parameter_name" {
  description = "SSM parameter holding the primary endpoint"
  value       = aws_ssm_parameter.primary_endpoint.name
}

output "reader_endpoint_parameter_name" {
  description = "SSM parameter holding the reader endpoint"
  value       = aws_ssm_parameter.reader_endpoint.name
}

output "port_parameter_name" {
  description = "SSM parameter holding the port"
  value       = aws_ssm_parameter.port.name
}

output "auth_secret_arn" {
  description = "ARN of the AUTH-token secret. Read from the secret version so consumers wait until a value exists"
  value       = aws_secretsmanager_secret_version.auth.arn
}
