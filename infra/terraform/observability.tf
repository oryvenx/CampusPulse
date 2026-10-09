resource "aws_cloudwatch_log_group" "api" {
  name              = "/${var.project_name}/api"
  retention_in_days = 7 # free-tier friendly
}
