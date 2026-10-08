resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"

  # Allow sign-in with username (simplest for demo)
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # MFA optional: leave off for demo, mention in report
  mfa_configuration = "OFF"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Enable USER_PASSWORD_AUTH so our FastAPI can do server-side login
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  generate_secret = false # simpler for demo; would use secret + SRP in prod

  access_token_validity  = 60 # minutes
  id_token_validity      = 60
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# ---- Groups ----
resource "aws_cognito_user_group" "staff" {
  name         = "staff"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Campus operations staff"
  precedence   = 1
}

resource "aws_cognito_user_group" "student" {
  name         = "student"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Students (read-only)"
  precedence   = 10
}

# ---- Seed users (dev only) ----
resource "aws_cognito_user" "staff1" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "staff1@campuspulse.local"

  attributes = {
    email          = "staff1@campuspulse.local"
    email_verified = "true"
    name           = "Ada Staff"
  }

  # Password set post-apply via CLI (Terraform can't set permanent password cleanly)
  # → run scripts/bootstrap_cognito_users.sh after apply
  message_action = "SUPPRESS"
}

resource "aws_cognito_user" "student1" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "student1@campuspulse.local"

  attributes = {
    email          = "student1@campuspulse.local"
    email_verified = "true"
    name           = "Sam Student"
  }

  message_action = "SUPPRESS"
}

resource "aws_cognito_user_in_group" "staff1_in_staff" {
  user_pool_id = aws_cognito_user_pool.main.id
  group_name   = aws_cognito_user_group.staff.name
  username     = aws_cognito_user.staff1.username
}

resource "aws_cognito_user_in_group" "student1_in_student" {
  user_pool_id = aws_cognito_user_pool.main.id
  group_name   = aws_cognito_user_group.student.name
  username     = aws_cognito_user.student1.username
}