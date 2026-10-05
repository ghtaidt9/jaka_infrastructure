output "identifier" {
  description = "RDS instance identifier (DBInstanceIdentifier dimension)"
  value       = aws_db_instance.this.identifier
}

output "address" {
  description = "Hostname of the instance"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port of the instance"
  value       = aws_db_instance.this.port
}

output "endpoint" {
  description = "host:port of the instance"
  value       = aws_db_instance.this.endpoint
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "admin_username" {
  description = "RDS master username"
  value       = var.admin_username
}

output "app_username" {
  description = "Login the app uses"
  value       = var.app_username
}

output "admin_secret_arn" {
  description = "ARN of the RDS-managed admin secret"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "app_secret_arn" {
  description = "ARN of the app-user secret. Read from the secret version so consumers wait until a value exists"
  value       = aws_secretsmanager_secret_version.app.arn
}

output "db_url_parameter_name" {
  description = "SSM parameter holding the JDBC URL"
  value       = aws_ssm_parameter.db_url.name
}
