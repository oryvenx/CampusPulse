# ------------------------------------------------------------------
# SSM Parameter Store — encrypted secrets for the application
#
# Encrypted with the AWS-managed KMS key alias/aws/ssm (free).
# The EC2 reads them at boot via user_data (see user_data.sh.tpl).
# ------------------------------------------------------------------

resource "aws_ssm_parameter" "sensor_api_key" {
  name        = "/${var.project_name}/sensor_api_key"
  description = "API key for simulated IoT sensors"
  type        = "SecureString"
  value       = var.sensor_api_key

  tags = { Name = "${var.project_name}-sensor-api-key" }
}

resource "aws_ssm_parameter" "cognito_user_pool_id" {
  name        = "/${var.project_name}/cognito_user_pool_id"
  description = "Cognito User Pool ID"
  type        = "String"
  value       = aws_cognito_user_pool.main.id

  tags = { Name = "${var.project_name}-cognito-pool" }
}

resource "aws_ssm_parameter" "cognito_client_id" {
  name        = "/${var.project_name}/cognito_client_id"
  description = "Cognito App Client ID"
  type        = "String"
  value       = aws_cognito_user_pool_client.app.id

  tags = { Name = "${var.project_name}-cognito-client" }
}

resource "aws_ssm_parameter" "cognito_region" {
  name        = "/${var.project_name}/cognito_region"
  description = "AWS region hosting the Cognito user pool"
  type        = "String"
  value       = var.aws_region

  tags = { Name = "${var.project_name}-cognito-region" }
}

resource "aws_ssm_parameter" "ec2_instance_id" {
  name        = "/${var.project_name}/ec2_instance_id"
  description = "Current EC2 instance ID — used by CI SSM Run Command target"
  type        = "String"
  value       = aws_instance.api.id

  tags = { Name = "${var.project_name}-ec2-instance-id" }
}
