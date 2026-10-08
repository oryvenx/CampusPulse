# ---- Latest Amazon Linux 2023 AMI ----
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ---- Security group ----
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "CampusPulse API EC2"
  vpc_id      = aws_vpc.main.id

  # SSH — your IP only
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # API port
  ingress {
    description = "CampusPulse API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # demo only; lock down to your IP in report
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---- Instance ----
resource "aws_instance" "api" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    aws_region        = var.aws_region
    events_table      = aws_dynamodb_table.events.name
    users_table       = aws_dynamodb_table.users.name
    cognito_user_pool = aws_cognito_user_pool.main.id
    cognito_client_id = aws_cognito_user_pool_client.app.id
    sensor_api_key    = var.sensor_api_key
    log_group         = aws_cloudwatch_log_group.api.name
    github_repo_url   = var.github_repo_url
    project_name      = var.project_name
  })

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-api" }
}

# ---- Elastic IP so the address doesn't change on stop/start ----
resource "aws_eip" "api" {
  instance = aws_instance.api.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-eip" }
}