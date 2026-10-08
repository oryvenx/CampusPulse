# CampusPulse 2026

Cloud-native Smart Campus Operations Platform for NorthBridge University.

## Stack
- Python 3.11 + FastAPI
- AWS: DynamoDB, Cognito, API Gateway, Lambda/EC2, CloudWatch, S3, Secrets Manager

## Quick Start (local dev)
```bash
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload