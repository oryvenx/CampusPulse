resource "aws_dynamodb_table" "events" {
  name         = "${var.project_name}-events"
  billing_mode = "PAY_PER_REQUEST" # free-tier friendly
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }
  attribute {
    name = "building"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }

  global_secondary_index {
    name            = "by_building_time"
    hash_key        = "building"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery { enabled = false } # free tier: keep off (costs)
  server_side_encryption { enabled = true }  # AWS-managed KMS key (free)
}

resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "username"

  attribute {
    name = "username"
    type = "S"
  }

  server_side_encryption { enabled = true }
}