output "service_arn" {
  description = "App Runner service ARN"
  value       = aws_apprunner_service.main.arn
}

output "service_id" {
  description = "App Runner service ID"
  value       = aws_apprunner_service.main.service_id
}

output "service_url" {
  description = "App Runner service URL"
  value       = aws_apprunner_service.main.service_url
}

output "custom_domain" {
  description = "Custom domain (if configured)"
  value       = var.domain
}

output "ecr_access_role_arn" {
  description = "ECR access role ARN"
  value       = aws_iam_role.ecr_access.arn
}

output "instance_role_arn" {
  description = "Instance role ARN"
  value       = aws_iam_role.instance.arn
}
