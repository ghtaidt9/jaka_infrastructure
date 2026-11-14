output "ecr_repository_urls" {
  description = "Full URL of each ECR repo"
  value       = module.ecr.repository_urls
}

output "ecr_registry" {
  description = "Registry part (before the /) for docker login"
  value       = split("/", values(module.ecr.repository_urls)[0])[0]
}

output "gha_ci_role_arn" {
  description = "ARN of the role GitHub Actions assumes"
  value       = aws_iam_role.gha_ci.arn
}