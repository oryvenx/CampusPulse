# CampusPulse 2026

**A cloud-native Smart Campus Operations Platform for NorthBridge University.**

CampusPulse ingests simulated IoT events (occupancy, energy, temperature, humidity, equipment failures, service requests) from buildings across campus, stores them in Amazon DynamoDB, evaluates operational thresholds server-side, and exposes a staff/student dashboard and REST API. All running on real AWS services in **`eu-west-3` (Paris)**.

> Built as the final project for the Cloud Computing course (2026 S2).
> Architecture, implementation, and deployment are fully infrastructure-as-code.

---

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Getting Started (Local Dev)](#getting-started-local-dev)
- [AWS Deployment](#aws-deployment)
- [Testing](#testing)
- [Authentication & Roles](#authentication--roles)
- [API Reference](#api-reference)
- [Observability](#observability)
- [Cost Control](#cost-control)
- [Roadmap](#roadmap)
- [Team](#team)

---

## Architecture

```
                    ┌────────────────────────────────────────────────┐
                    │              User Browser (HTTPS)               │
                    └───────────────────────┬────────────────────────┘
                                            │
                                            ▼
                    ┌────────────────────────────────────────────────┐
                    │        Amazon CloudFront (global edge)         │
                    │                                                │
                    │   /  /assets/*          →  S3 bucket (SPA)     │
                    │   /api/*                →  EC2 FastAPI         │
                    └──────────┬──────────────────────┬──────────────┘
                               │                      │
                    ┌──────────▼──────────┐  ┌────────▼─────────────────┐
                    │   Amazon S3         │  │  Amazon EC2 (t3.micro)   │
                    │   SPA static assets │  │  FastAPI + Uvicorn       │
                    │   (Vite + React)    │  │  systemd managed         │
                    └─────────────────────┘  └────────┬─────────────────┘
                                                      │
                    ┌─────────────────────────────────┼──────────────────┐
                    │                                 │                  │
                    ▼                                 ▼                  ▼
          ┌─────────────────┐              ┌──────────────────┐  ┌───────────────┐
          │   DynamoDB      │              │  Amazon Cognito  │  │ CloudWatch    │
          │   events table  │              │  User Pool       │  │ Logs + Alarms │
          │   users table   │              │  groups:         │  │ Dashboard     │
          │   GSI by_bldg   │              │   staff/student  │  └───────────────┘
          └─────────────────┘              └──────────────────┘
                    ▲
                    │  events via X-Sensor-Api-Key
          ┌─────────┴─────────┐
          │   Simulator       │
          │   (Python)        │
          └───────────────────┘
```

**Key design decisions:**

| Concern | Choice | Rationale |
|---|---|---|
| Frontend hosting | S3 + CloudFront | Cloud-native, HTTPS by default, free-tier friendly, cache at edge |
| Backend | EC2 t3.micro + systemd | Direct control, easy debugging, free-tier eligible (750h/mo) |
| API path | `/api/*` on CloudFront → EC2 | Same-origin for browser → **no CORS** |
| Storage | DynamoDB on-demand | Pay-per-request, serverless, GSI for `building`+`timestamp` |
| Auth | Amazon Cognito User Pool + groups | Managed, JWT-based, group claims for RBAC |
| Logs | Structured JSON → CloudWatch | Queryable, metric filters → alarms |
| IaC | Terraform | Provider-agnostic, one-command provisioning |

---

## Features

### Functional

- **Real-time event ingestion** from simulated campus IoT sources
- **Persistent storage** in DynamoDB with efficient querying by building + time
- **Server-side alert engine** — evaluates thresholds independent of the client
- **Role-based access control** — `staff` (read/write) vs `student` (read-only)
- **Sensor authentication** — API key for headless devices, JWT for humans
- **Live dashboard** — metric cards, alerts-over-time chart, energy-by-building chart
- **Filterable views** — alerts by severity, events by building/type/severity

### Cloud / Operational

- **100% Infrastructure as Code** — `terraform apply` provisions everything
- **One-command deploy** — `./scripts/deploy_app.sh` and `./scripts/deploy_frontend.sh`
- **Structured JSON logs** — every request produces a queryable log line
- **CloudWatch alarms** — 5xx error rate alarms to a CloudWatch dashboard
- **Elastic IP** — stable public endpoint across EC2 restarts/rebuilds
- **Free-tier discipline** — every service chosen to stay within AWS free tier

---

## Tech Stack

### Backend
- **Python 3.11**
- **FastAPI** — async REST framework
- **Uvicorn** — ASGI server
- **Pydantic v2** — schema validation
- **boto3** — AWS SDK (DynamoDB, Cognito, CloudWatch)
- **python-jose** — JWT verification against Cognito JWKS
- **structlog** — structured JSON logging

### Frontend
- **React 18** + **TypeScript 5.6**
- **Vite 5** — build tooling
- **Tailwind CSS 3** — styling
- **shadcn/ui** — component primitives (Radix UI under the hood)
- **TanStack Query** — data fetching + cache
- **React Router 6** — client-side routing
- **Recharts** — charts
- **Lucide** — icons

### AWS
| Service | Purpose |
|---|---|
| **EC2 (t3.micro)** | FastAPI backend host |
| **Elastic IP** | Stable public endpoint |
| **S3** | SPA static asset hosting |
| **CloudFront** | CDN + HTTPS + API reverse proxy |
| **DynamoDB** | Events + users tables |
| **Cognito** | User pool + app client + groups |
| **CloudWatch** | Logs, metrics, alarms, dashboard |
| **IAM** | Roles + least-privilege policies |
| **VPC / Security Groups** | Network isolation |
| **SSM Parameter Store** | Secrets (Task 8 — in progress) |

### DevOps
- **Terraform** — IaC
- **GitHub Actions** — CI/CD (Task 9 — planned)

---

## Repository Layout

```
CampusPulse/
├── app/                      # FastAPI backend
│   ├── main.py               # App entrypoint
│   ├── config.py             # Settings (env-driven)
│   ├── logging_config.py     # structlog setup
│   ├── middleware.py         # Request-id + access logging
│   ├── models/               # Pydantic schemas + campus topology
│   ├── routers/              # /auth, /events, /alerts
│   └── services/             # DynamoDB, Cognito, alert engine
│
├── dashboard/                # Vite + React SPA
│   ├── src/
│   │   ├── components/       # Layout + shadcn/ui primitives
│   │   ├── pages/            # Login, Overview, Alerts, Events
│   │   ├── lib/              # api.ts, auth.tsx, types.ts, utils.ts
│   │   └── App.tsx           # Router
│   ├── vite.config.ts        # Alias + API proxy
│   └── package.json
│
├── simulator/                # Event generator
│   └── generate_events.py    # Sends events to /api/events
│
├── infra/terraform/          # All AWS infra
│   ├── main.tf               # Provider config
│   ├── variables.tf          # Inputs
│   ├── network.tf            # VPC, subnet, IGW, route table
│   ├── compute.tf            # EC2 + EIP + security group
│   ├── database.tf           # DynamoDB tables
│   ├── cognito.tf            # User pool + client + groups
│   ├── iam.tf                # EC2 role + inline policy
│   ├── observability.tf      # CloudWatch log group
│   ├── frontend.tf           # S3 + CloudFront + API routing
│   ├── alarms.tf             # Metric filters + alarm + dashboard
│   ├── user_data.sh.tpl      # EC2 cloud-init bootstrap
│   ├── outputs.tf            # Public IDs / URLs
│   └── terraform.tfvars      # NOT committed (gitignored)
│
├── scripts/
│   ├── deploy_app.sh         # Backend deploy (git pull + restart)
│   ├── deploy_frontend.sh    # SPA build + S3 sync + CF invalidation
│   ├── bootstrap_cognito_users.sh  # Set Cognito user passwords
│   ├── ec2.sh                # Start / stop / status helper
│   ├── test_cognito.sh       # RBAC smoke test
│   └── test_alert.sh         # Alerts smoke test
│
├── tests/                    # pytest (Task 10)
├── docs/                     # Architecture notes
├── requirements.txt
└── README.md
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Python | 3.11 or 3.13 | `brew install python@3.11` |
| Node.js | ≥18 | `brew install node@20` |
| AWS CLI | v2 | `brew install awscli` |
| Terraform | ≥1.7 | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` |
| AWS account | — | With budget alert + IAM user |

**AWS setup (one-time):**

1. Create an IAM user `campuspulse-dev` with **programmatic access** and attach `AdministratorAccess` (documented trade-off — see report §Security).
2. Configure the CLI:
   ```bash
   aws configure
   # Access key, Secret key
   # Default region: eu-west-3
   # Output: json
   ```
3. Create an EC2 key pair named `campuspulse-key` in **`eu-west-3`**, download the `.pem`, save it at `~/.ssh/campuspulse-key.pem`, and `chmod 400` it.
4. Set up a **budget alert** at $1 (AWS Console → Billing → Budgets).

---

## Getting Started (Local Dev)

### 1. Clone + setup

```bash
git clone https://github.com/oryvenx/CampusPulse.git
cd CampusPulse

python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Provision AWS infrastructure

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   admin_cidr      = "<your public IP>/32"       (get with: curl https://checkip.amazonaws.com)
#   key_pair_name   = "campuspulse-key"
#   github_repo_url = "https://github.com/oryvenx/CampusPulse.git"
#   sensor_api_key  = "<random 48 hex chars>"     (openssl rand -hex 24)

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Provisions:** VPC, EC2 `t3.micro` (with cloud-init bootstrap), Elastic IP, 2 DynamoDB tables, Cognito user pool + client + 2 groups + 2 users, IAM role/policy, CloudWatch log group, S3 bucket, CloudFront distribution, metric filters, alarm, dashboard. **~28 resources.**

### 3. Set Cognito user passwords

```bash
cd ../..
./scripts/bootstrap_cognito_users.sh $(cd infra/terraform && terraform output -raw cognito_user_pool_id)
# → staff1@campuspulse.local   / Staff#2026Pass
# → student1@campuspulse.local / Student#2026Pass
```

### 4. Deploy backend + frontend

```bash
./scripts/deploy_app.sh          # git pull + pip install + systemctl restart
./scripts/deploy_frontend.sh     # npm build + s3 sync + cloudfront invalidate
```

### 5. Access the app

```bash
cd infra/terraform
terraform output cloudfront_url
# → https://dxxxxxxxxxxxxx.cloudfront.net
```

Open in browser. Sign in as `staff1@campuspulse.local` / `Staff#2026Pass`.

### 6. Frontend dev mode (optional)

To develop the SPA locally with hot reload against the deployed API:

```bash
cd dashboard
npm install
npm run dev
# → http://localhost:5173
```

The dev server proxies `/api/*` to the EC2 (`vite.config.ts`).

---

## AWS Deployment

Everything is Terraform + shell scripts.

### Full stack

```bash
cd infra/terraform
terraform apply -auto-approve
cd ../..
./scripts/bootstrap_cognito_users.sh $(cd infra/terraform && terraform output -raw cognito_user_pool_id)
./scripts/deploy_app.sh
./scripts/deploy_frontend.sh
```

### Redeploy backend only

```bash
./scripts/deploy_app.sh
```

### Redeploy frontend only

```bash
./scripts/deploy_frontend.sh
```

### Stop / start EC2 (cost discipline)

```bash
./scripts/ec2.sh stop     # ⚠️ do this when you're done for the day
./scripts/ec2.sh start
./scripts/ec2.sh status
```

The **Elastic IP never changes** across stop/start. The CloudFront URL never changes.

---

## Testing

### RBAC smoke test

```bash
export SENSOR_API_KEY=$(grep sensor_api_key infra/terraform/terraform.tfvars | cut -d'"' -f2)
./scripts/test_cognito.sh
```

Expected matrix:

```
no-auth   GET /events:  401
student   GET /events:  200
student   POST /events: 403
staff     POST /events: 201
sensor    POST /events: 201
no-auth   GET /stats:   401
student   GET /stats:   200
```

### Alerts smoke test

```bash
./scripts/test_alert.sh
```

Forces critical events, checks the alerts feed, verifies `?severity=critical` filter, checks the by-building summary.

### Verify against real AWS

```bash
# Event landed in DynamoDB?
aws dynamodb scan --table-name campuspulse-events \
  --region eu-west-3 --max-items 5 \
  --query 'Items[].{id:event_id.S,building:building.S,value:value.N}'

# Logs in CloudWatch?
aws logs describe-log-streams \
  --log-group-name /campuspulse/api \
  --region eu-west-3 --order-by LastEventTime --descending \
  --query 'logStreams[0].logStreamName' --output text
```

---

## Authentication & Roles

All authentication goes through **Amazon Cognito**.

### Two roles

| Group | Capabilities |
|---|---|
| `staff` | Read everything, **write events**, see alerts |
| `student` | Read events + stats only. **No** alerts, **no** writes. |

### Two auth paths

1. **Humans** — Bearer JWT issued by Cognito (`POST /api/auth/login` with email + password, `USER_PASSWORD_AUTH` flow). Token verified server-side against the user pool's JWKS.
2. **Devices (simulated sensors)** — `X-Sensor-Api-Key` header. Key stored in SSM Parameter Store; loaded into the process at startup.

### Test credentials

```
staff1@campuspulse.local   / Staff#2026Pass
student1@campuspulse.local / Student#2026Pass
```

---

## API Reference

Base URL (via CloudFront): `https://<cloudfront-domain>/api`

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/auth/login` | none | Cognito login → JWT |
| `GET` | `/api/auth/me` | JWT | Current user's claims |
| `POST` | `/api/events` | staff JWT **or** `X-Sensor-Api-Key` | Ingest an event |
| `GET` | `/api/events` | JWT | List events (filters: `building`, `event_type`, `severity`, `limit`) |
| `GET` | `/api/stats` | JWT | Per-building aggregates |
| `GET` | `/api/alerts` | staff JWT | Server-evaluated alerts (filters: `building`, `severity`) |
| `GET` | `/api/health` | none | Liveness probe |

### Event schema

```json
{
  "event_id":   "evt-2026-1f6218c7",
  "building":   "Library-A",
  "room":       "A203",
  "event_type": "occupancy",
  "value":      42,
  "unit":       "people",
  "severity":   "normal",
  "timestamp":  "2026-10-08T14:32:37.587Z"
}
```

Event types: `occupancy`, `temperature`, `humidity`, `energy`, `door`, `equipment_failure`, `service_request`.

### Simulator

```bash
export SENSOR_API_KEY=<key from terraform.tfvars>
python -m simulator.generate_events --count 30 \
  --url https://<cloudfront-domain>/api/events
```

Options: `--count N`, `--loop SECONDS`, `--dry-run`.

---

## Observability

### Structured logs

Every request produces a JSON line:

```json
{"event":"request","method":"GET","path":"/api/health","status":200,
 "duration_ms":2.1,"request_id":"a1b2c3d4e5f6","level":"info",
 "timestamp":"2026-10-09T08:19:55.165867Z","logger":"access"}
```

Locally: `journalctl -u campuspulse -f`
Remotely: **CloudWatch Logs** → `/campuspulse/api`

### Metrics & alarms

| Metric filter | Source | Alarm |
|---|---|---|
| `Api5xxCount` | logs matching `$.status >= 500` | `campuspulse-api-5xx-high` (Sum > 5 / 5 min) |
| `Api4xxCount` | logs matching `$.status >= 400 && $.status < 500` | — |

### Dashboard

CloudWatch dashboard **`campuspulse-ops`** — 5xx, 4xx, EC2 memory usage.

### Viewing logs

```bash
STREAM=$(aws logs describe-log-streams \
  --log-group-name /campuspulse/api \
  --region eu-west-3 --order-by LastEventTime --descending \
  --query 'logStreams[0].logStreamName' --output text)

aws logs get-log-events \
  --log-group-name /campuspulse/api \
  --log-stream-name "$STREAM" \
  --region eu-west-3 --limit 20 \
  --query 'events[].message' --output text
```

---

## Cost Control

### Free-tier posture

| Service | Free-tier allowance | Actual usage |
|---|---|---|
| EC2 t3.micro | 750 h/mo (12 mo) | ~60 h/mo (stopped at night) |
| DynamoDB | 25 GB + 200M req/mo | < 1 GB |
| Cognito | 50,000 MAU | 2 |
| CloudFront | 1 TB out + 10M req/mo | < 1 GB |
| S3 | 5 GB + 20K GET/mo | < 100 MB |
| CloudWatch Logs | 5 GB ingest/mo | < 50 MB |
| CloudWatch metrics | 10 custom / mo free | ~4 |
| IAM, VPC, SG, EIP (attached) | free | — |

### Rules of engagement

1. **`./scripts/ec2.sh stop`** when done for the day
2. **Never `terraform destroy`** mid-project — you'd lose Cognito passwords, DynamoDB data, and get a new Elastic IP. Just **stop** the instance.
3. **Budget alert** set at $1 (see Prerequisites)
4. **Verify weekly:** AWS Console → Billing → Bills

### Estimated monthly cost (with stopping)

**$0.00 – $0.10** during the project lifetime, comfortably inside free tier.

---

## Roadmap

- [x] Task 1 — Repository scaffold
- [x] Task 1.5 — Terraform AWS baseline
- [x] Task 2 — Event model + simulator
- [x] Task 3 — Real DynamoDB wiring
- [x] Task 4 — Amazon Cognito auth + RBAC
- [x] Task 5 — Server-side alert engine
- [x] Task 6A — Vite + React + TS + Tailwind SPA scaffold
- [x] Task 6B — SPA components (login, overview, alerts, events)
- [x] Task 6C — S3 + CloudFront deploy + `/api/*` routing
- [x] Task 7 — CloudWatch Agent, JSON logs, alarms, dashboard
- [ ] **Task 8 — SSM Parameter Store for the sensor key** *(next)*
- [ ] Task 9 — CI/CD via GitHub Actions
- [ ] Task 10 — Final tests + implementation report

---

## Team

| Name | Role | Contact |
|---|---|---|
| *Your name* | Cloud architecture, backend, frontend, IaC | — |
| *Teammate 2* | *Add here* | — |
| *Teammate 3* | *Add here* | — |

---

## License

Academic project — NorthBridge University, 2026.
