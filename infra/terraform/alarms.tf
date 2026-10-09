# ------------------------------------------------------------------
# CloudWatch Alarms, Metric Filters, and Dashboard
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# Log-based metric filters
# ------------------------------------------------------------------

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

# ------------------------------------------------------------------
# Alarm: API 5xx spike
# ------------------------------------------------------------------

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

# ------------------------------------------------------------------
# CloudWatch Dashboard
# ------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-ops"

  dashboard_body = jsonencode({
    widgets = [
      # ---- Row 1: API errors ----
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "API 5xx errors"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["CampusPulse/API", "Api5xxCount"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "API 4xx errors"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["CampusPulse/API", "Api4xxCount"]
          ]
        }
      },

      # ---- Row 2: EC2 CPU (native AWS metric, always available) ----
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU utilization (%)"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              aws_instance.api.id,
              { label = "CPU %" }
            ]
          ]
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },

      # ---- Row 2, right: recent API requests log tail ----
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Recent API requests"
          region = var.aws_region
          query  = "SOURCE '${aws_cloudwatch_log_group.api.name}' | fields @timestamp, method, path, status, duration_ms | filter event = 'request' | sort @timestamp desc | limit 25"
          view   = "table"
        }
      },
    ]
  })
}
