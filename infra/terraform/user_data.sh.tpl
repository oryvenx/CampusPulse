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

# ---- 5. Fetch secrets from SSM Parameter Store ----
fetch_ssm() {
  aws ssm get-parameter \
    --region "${aws_region}" \
    --name "$1" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text
}

SENSOR_API_KEY_VAL="$(fetch_ssm "/${project_name}/sensor_api_key")"
COGNITO_USER_POOL_ID_VAL="$(fetch_ssm "/${project_name}/cognito_user_pool_id")"
COGNITO_CLIENT_ID_VAL="$(fetch_ssm "/${project_name}/cognito_client_id")"
COGNITO_REGION_VAL="$(fetch_ssm "/${project_name}/cognito_region")"

# ---- 6. Environment file ----
cat > /opt/campuspulse/env <<EOF
APP_ENV=prod
AWS_REGION=${aws_region}
EVENTS_TABLE=${events_table}
USERS_TABLE=${users_table}
COGNITO_USER_POOL_ID=$COGNITO_USER_POOL_ID_VAL
COGNITO_CLIENT_ID=$COGNITO_CLIENT_ID_VAL
COGNITO_REGION=$COGNITO_REGION_VAL
SENSOR_API_KEY=$SENSOR_API_KEY_VAL
LOG_GROUP=${log_group}
EOF
chmod 600 /opt/campuspulse/env

# ---- 7. Log directory ----
mkdir -p /var/log/campuspulse
touch /var/log/campuspulse/app.log
chown -R ec2-user:ec2-user /var/log/campuspulse
chmod 755 /var/log/campuspulse
chmod 644 /var/log/campuspulse/app.log

# ---- 8. systemd unit ----
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

StandardOutput=append:/var/log/campuspulse/app.log
StandardError=append:/var/log/campuspulse/app.log

[Install]
WantedBy=multi-user.target
UNIT

chown -R ec2-user:ec2-user /opt/campuspulse

systemctl daemon-reload
systemctl enable campuspulse
systemctl start campuspulse || true

# ================================================================
# CloudWatch Agent
# ================================================================

# ---- 9. CW agent config (native metric names — no rename) ----
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

sed -i "s|LOG_GROUP_PLACEHOLDER|${log_group}|g" \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ---- 10. Start CW agent ----
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent

echo "CampusPulse bootstrap complete"