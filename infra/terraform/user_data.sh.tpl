#!/bin/bash
set -euxo pipefail

# ================================================================
# CampusPulse 2026 — EC2 bootstrap
# Amazon Linux 2023 + Python 3.11 + FastAPI + CloudWatch Agent
# ================================================================

# ---- 1. System packages ----
dnf update -y
dnf install -y python3.11 python3.11-pip git nginx amazon-cloudwatch-agent

# ---- 2. Application directory ----
mkdir -p /opt/campuspulse
cd /opt/campuspulse

# ---- 3. Clone the repo ----
git clone ${github_repo_url} repo
cd repo

# ---- 4. Python virtualenv ----
python3.11 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip -q
pip install -q -r requirements.txt

# ---- 5. Environment file ----
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

# ---- 6. Log directory ----
mkdir -p /var/log/campuspulse
touch /var/log/campuspulse/app.log
chown -R ec2-user:ec2-user /var/log/campuspulse
chmod 755 /var/log/campuspulse
chmod 644 /var/log/campuspulse/app.log

# ---- 7. systemd unit (writes to file so CloudWatch Agent can tail it) ----
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

# Structured JSON logs go to a file the CloudWatch Agent can tail
StandardOutput=append:/var/log/campuspulse/app.log
StandardError=append:/var/log/campuspulse/app.log

[Install]
WantedBy=multi-user.target
UNIT

# ---- 8. Ownership ----
chown -R ec2-user:ec2-user /opt/campuspulse

# ---- 9. Enable + start the app ----
systemctl daemon-reload
systemctl enable campuspulse
systemctl start campuspulse || true   # will fail until app code supports it; ignored

# ================================================================
# CloudWatch Agent
# ================================================================

# ---- 10. CloudWatch Agent configuration ----
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/campuspulse/app.log",
            "log_group_name": "LOG_GROUP_PLACEHOLDER",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC",
            "retention_in_days": 7
          }
        ]
      }
    }
  },
    "metrics": {
        "namespace": "CampusPulse/API",
        "append_dimensions": {
            "InstanceId": "$${aws:InstanceId}"
        },
        "aggregation_dimensions": [["InstanceId"]],
        "metrics_collected": {
            "mem": {
            "measurement": [
                {"name": "mem_used_percent", "unit": "Percent"}
            ],
            "metrics_collection_interval": 60
            },
            "disk": {
            "measurement": [
                {"name": "used_percent", "unit": "Percent"}
            ],
            "resources": ["/"],
            "metrics_collection_interval": 60
            },
            "cpu": {
            "measurement": [
                {"name": "cpu_usage_idle", "unit": "Percent"},
                {"name": "cpu_usage_user", "unit": "Percent"},
                {"name": "cpu_usage_system", "unit": "Percent"}
            ],
            "totalcpu": true,
            "metrics_collection_interval": 60
            }
        }
    }
}
CWCONF

# Substitute the log group name (bash heredoc can't interpolate inside quoted EOF)
sed -i "s|LOG_GROUP_PLACEHOLDER|${log_group}|g" \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ---- 11. Start CloudWatch Agent ----
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent

# ---- 12. Done ----
echo "CampusPulse bootstrap complete"