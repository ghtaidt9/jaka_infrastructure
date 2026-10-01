output "kms_key_arn" {
  description = "ARN of the KMS key encrypting every application secret"
  value       = aws_kms_key.secrets.arn
}

output "kms_key_id" {
  description = "ID of the KMS key encrypting every application secret"
  value       = aws_kms_key.secrets.key_id
}

output "ssm_caller_username" {
  description = "IAM user allowed to start SSM session (null when not created)"
  value       = one(aws_iam_user.ssm_caller[*].name)
}
