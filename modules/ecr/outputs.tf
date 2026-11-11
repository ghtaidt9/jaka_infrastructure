output "repository_urls" {
  description = "ECR repository URL for this service's images"
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}
