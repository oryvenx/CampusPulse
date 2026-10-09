output "state_bucket" {
  value       = aws_s3_bucket.tfstate.id
  description = "S3 bucket name — copy this into infra/terraform/main.tf backend block"
}

output "lock_table" {
  value       = aws_dynamodb_table.tfstate_lock.name
  description = "DynamoDB lock table name"
}
