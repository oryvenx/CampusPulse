# ---- EC2 assume role ----
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# ---- Inline policy: what the EC2 is allowed to do ----
data "aws_iam_policy_document" "ec2_permissions" {
  statement {
    sid    = "DynamoDBEvents"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DescribeTable",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      aws_dynamodb_table.events.arn,
      "${aws_dynamodb_table.events.arn}/index/*",
      aws_dynamodb_table.users.arn,
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
    ]
    resources = [
      aws_cloudwatch_log_group.api.arn,
      "${aws_cloudwatch_log_group.api.arn}:*",
    ]
  }

  statement {
    sid       = "CloudWatchMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  statement {
    sid    = "EC2Describe"
    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SSMReadProjectSecrets"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*",
    ]
  }

  statement {
    sid    = "SSMReadCloudWatchAgent"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/AmazonCloudWatch-*",
    ]
  }

  statement {
    sid    = "CognitoRead"
    effect = "Allow"
    actions = [
      "cognito-idp:InitiateAuth",
      "cognito-idp:AdminGetUser",
      "cognito-idp:ListUsers",
      "cognito-idp:AdminAddUserToGroup",
    ]
    resources = [aws_cognito_user_pool.main.arn]
  }

  statement {
    sid     = "SSMRead"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_policy" {
  name   = "${var.project_name}-ec2-policy"
  policy = data.aws_iam_policy_document.ec2_permissions.json
}

resource "aws_iam_role_policy_attachment" "ec2_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

# AWS-managed policy: required for SSM agent on the instance
resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ------------------------------------------------------------------
# GitHub Actions deploy user (scoped, not admin)
# ------------------------------------------------------------------

resource "aws_iam_user" "gha_deployer" {
  name = "${var.project_name}-gha-deployer"

  tags = { Name = "${var.project_name}-gha-deployer" }
}

data "aws_iam_policy_document" "gha_deployer" {
  # --- SSM Run Command: send + read result, but only against our instance ---
  statement {
    sid    = "SSMSendCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.api.id}",
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
    ]
  }

  statement {
    sid    = "SSMReadCommandResult"
    effect = "Allow"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:ListCommands",
    ]
    resources = ["*"]
  }

  # --- S3: sync the SPA (upload + delete for --delete flag) ---
  statement {
    sid    = "S3SyncFrontend"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.frontend.arn}/*",
    ]
  }

  statement {
    sid       = "S3ListFrontendBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.frontend.arn]
  }

  # --- CloudFront: invalidate the SPA cache after deploy ---
  statement {
    sid    = "CloudFrontInvalidate"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]
    resources = [
      "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.frontend.id}",
    ]
  }

  # --- Read Terraform outputs during CI (optional, for /campuspulse/* lookups) ---
  statement {
    sid    = "SSMReadDeployParams"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*",
    ]
  }

  statement {
    sid    = "DynamoDBTestWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.events.arn,
      "${aws_dynamodb_table.events.arn}/index/*",
    ]
  }
}


resource "aws_iam_policy" "gha_deployer" {
  name   = "${var.project_name}-gha-deployer-policy"
  policy = data.aws_iam_policy_document.gha_deployer.json
}

resource "aws_iam_user_policy_attachment" "gha_deployer" {
  user       = aws_iam_user.gha_deployer.name
  policy_arn = aws_iam_policy.gha_deployer.arn
}

# Programmatic access key for GitHub Actions
resource "aws_iam_access_key" "gha_deployer" {
  user = aws_iam_user.gha_deployer.name
}