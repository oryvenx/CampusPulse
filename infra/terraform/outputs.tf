output "api_public_ip" {
  value       = aws_eip.api.public_ip
  description = "Public IP of the API EC2"
}

output "api_url" {
  value       = "http://${aws_eip.api.public_ip}:8000"
  description = "Base URL of the API"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.api.public_ip}"
  description = "SSH command to connect"
}

output "dynamodb_events_table" {
  value = aws_dynamodb_table.events.name
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.app.id
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.api.name
}

output "frontend_bucket" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "gha_deployer_access_key_id" {
  value       = aws_iam_access_key.gha_deployer.id
  description = "Access key ID for GitHub Actions (put in repo secret AWS_ACCESS_KEY_ID)"
}

output "gha_deployer_secret_access_key" {
  value       = aws_iam_access_key.gha_deployer.secret
  sensitive   = true
  description = "Secret access key for GitHub Actions (put in repo secret AWS_SECRET_ACCESS_KEY)"
}

output "ec2_instance_id" {
  value       = aws_instance.api.id
  description = "EC2 instance ID (target of SSM Run Command)"
}