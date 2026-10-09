#!/usr/bin/env bash
set -euo pipefail
ACTION="${1:?usage: ec2.sh start|stop|status}"

ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=campuspulse-api" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region eu-west-3)

case "$ACTION" in
  start)  aws ec2 start-instances --instance-ids "$ID" --region eu-west-3 ;;
  stop)   aws ec2 stop-instances  --instance-ids "$ID" --region eu-west-3 ;;
  status) aws ec2 describe-instances --instance-ids "$ID" --region eu-west-3 \
            --query 'Reservations[0].Instances[0].State.Name' --output text ;;
  *) echo "unknown action: $ACTION"; exit 1 ;;
esac
