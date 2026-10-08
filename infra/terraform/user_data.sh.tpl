#!/bin/bash
set -euxo pipefail

# ---- System packages ----
dnf update -y
dnf install -y python3.11 python3.11-pip git nginx

# ---- App directory ----
mkdir -p /opt/campuspulse
cd /opt/campuspulse

# ---- Clone the repo ----
git clone ${github_repo_url} repo
cd repo

# ---- Python venv ----
python3.11 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# ---- Env file for systemd ----
cat > /opt/campuspulse/env <<EOF
APP_ENV=prod
AWS_REGION=${aws_region}
EVENTS_TABLE=${events_table}
USERS_TABLE=${users_table}
COGNITO_USER_POOL_ID=${cognito_user_pool}
COGNITO_CLIENT_ID=${cognito_client_id}
COGNITO_REGION=${aws_region}
SENSOR_API_KEY=${sensor_api_key}
LOG_GROUP=${log_group}
EOF
chmod 600 /opt/campuspulse/env

# ---- systemd unit ----
cat > /etc/systemd/system/campuspulse.service <<'UNIT'
[Unit]
Description=CampusPulse FastAPI
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/campuspulse/repo
EnvironmentFile=/opt/campuspulse/env
ExecStart=/opt/campuspulse/repo/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

chown -R ec2-user:ec2-user /opt/campuspulse

systemctl daemon-reload
systemctl enable campuspulse
systemctl start campuspulse