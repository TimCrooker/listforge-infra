output "endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "Database address"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "Master username"
  value       = aws_db_instance.main.username
}

output "password_secret_arn" {
  description = "ARN of the password secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "connection_url" {
  description = "Database connection URL"
  value       = "postgresql://${aws_db_instance.main.username}:${random_password.master.result}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}?sslmode=require"
  sensitive   = true
}
