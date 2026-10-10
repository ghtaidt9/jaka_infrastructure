output "state_bucket" {
  description = "Bucket name to put in envs/*/backend.hcl"
  value       = aws_s3_bucket.tfstate.id
}

output "account_id" {
  description = "Account ID that replaces <ACCOUNT_ID> in envs/*/backend.hcl"
  value       = data.aws_caller_identity.current.account_id
}
