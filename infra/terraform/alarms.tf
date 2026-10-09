# ------------------------------------------------------------------
# CloudWatch Alarms
# ------------------------------------------------------------------

# Alarm: 5xx error spike (based on API Gateway metric — not applicable to EC2)
# Instead, we use Logs Metric Filters to turn logs into metrics.

resource "aws_cloudwatch_log_metric_filter" "http_5xx" {
  name           = "${var.project_name}-api-5xx"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.status >= 500 }"

  metric_transformation {
    name          = "Api5xxCount"
    namespace     = "CampusPulse/API"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "http_4xx" {
  name           = "${var.project_name}-api-4xx"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.status >= 400 && $.status < 500 }"

  metric_transformation {
    name          = "Api4xxCount"
    namespace     = "CampusPulse/API"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-api-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Api5xxCount"
  namespace           = "CampusPulse/API"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "More than 5 API 5xx errors in 5 minutes"

  treat_missing_data = "notBreaching"
}