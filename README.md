# CampusPulse 2026
---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Python | 3.11 or 3.13 | `brew install python@3.11` |
| Node.js | >=18 | `brew install node@20` |
| AWS CLI | v2 | `brew install awscli` |
| Terraform | >=1.7 | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` |
| jq | latest | `brew install jq` |

You also need:

- An AWS account with **AdministratorAccess** (or equivalent) on your IAM user
- A **budget alert** configured in AWS Billing → Budgets (recommended: $1)
- An **EC2 key pair** named `campuspulse-key` created in `eu-west-3`, saved to `~/.ssh/campuspulse-key.pem` with `chmod 400`
- A **GitHub repository** for the project

---

## 1. Clone and configure

```bash
git clone https://github.com/oryvenx/CampusPulse.git
cd CampusPulse
```

### 1.1 Configure AWS CLI

```bash
aws configure
```

Enter:

```
AWS Access Key ID:     <your IAM user access key>
AWS Secret Access Key: <your IAM user secret>
Default region name:   eu-west-3
Default output format: json
```

Verify:

```bash
aws sts get-caller-identity
```

Expected output (your account ID will differ):

```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/<your-iam-user>"
}
```

### 1.2 Create the EC2 key pair

```bash
# List existing key pairs in the target region
aws ec2 describe-key-pairs --region eu-west-3 --query 'KeyPairs[].KeyName' --output text

# If `campuspulse-key` is not listed, create it
aws ec2 create-key-pair \
  --region eu-west-3 \
  --key-name campuspulse-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/campuspulse-key.pem

# Restrict permissions
chmod 400 ~/.ssh/campuspulse-key.pem

# Verify
ls -la ~/.ssh/campuspulse-key.pem
```

If you already have a key pair by that name, download the `.pem` from the AWS Console → EC2 → Key Pairs → `campuspulse-key` → **Actions → Download key pair**, and move it to `~/.ssh/campuspulse-key.pem`.

### 1.3 Get your public IP (needed for `terraform.tfvars`)

```bash
curl -s https://checkip.amazonaws.com
```

Note the output, e.g. `203.0.113.42`. You will append `/32` to it later for the SSH ingress rule.

---

## 2. Provision AWS infrastructure

### 2.1 Create `terraform.tfvars`

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. Replace each placeholder with your real values:

```hcl
aws_region      = "eu-west-3"
project_name    = "campuspulse"
environment     = "dev"

# Replace with the IP from step 1.3, with /32 appended
admin_cidr      = "203.0.113.42/32"

instance_type   = "t3.micro"
key_pair_name   = "campuspulse-key"

# Replace with the HTTPS URL of your fork
github_repo_url = "https://github.com/<your-username>/CampusPulse.git"

# Generate a fresh 48-hex-char key — do NOT reuse an existing one
sensor_api_key  = "<48 hex characters>"
```

### 2.2 Generate the sensor API key

```bash
openssl rand -hex 24
```

Copy the output. Paste it as the value of `sensor_api_key` in `terraform.tfvars`.

**Store this key in a password manager.** It is a real secret. Never commit `terraform.tfvars` — it's already in `.gitignore`.

### 2.3 Apply

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Provisions: VPC, subnet, internet gateway, route table, security group, EC2 `t3.micro`, Elastic IP, 2 DynamoDB tables, Cognito user pool + app client + 2 groups + 2 users, IAM role/policy, CloudWatch log group + metric filters + alarm + dashboard, S3 bucket, CloudFront distribution, 4 SSM parameters, GitHub Actions IAM user.

Wait 90 seconds after apply completes for the EC2 to finish cloud-init.

### 2.4 Capture Terraform outputs

```bash
terraform output
```

Note the values. You will need them for the following steps:

| Output | Use |
|---|---|
| `api_public_ip` | `deploy_app.sh` target, SSH |
| `api_url` | Health-check URL |
| `cloudfront_url` | User-facing app URL |
| `cognito_user_pool_id` | `.env` + `bootstrap_cognito_users.sh` |
| `cognito_client_id` | `.env` |
| `dynamodb_events_table` | `.env` + verification |
| `frontend_bucket` | GitHub Actions secret |
| `cloudfront_distribution_id` | GitHub Actions secret |
| `ec2_instance_id` | SSM target |
| `cloudwatch_log_group` | CloudWatch logs |
| `gha_deployer_access_key_id` | GitHub Actions secret |
| `gha_deployer_secret_access_key` | GitHub Actions secret (sensitive) |

### 2.5 Save the GitHub Actions credentials to a password manager

```bash
echo "Access Key ID:"
terraform output -raw gha_deployer_access_key_id
echo

echo "Secret Access Key:"
terraform output -raw gha_deployer_secret_access_key
echo
```

**The secret is only visible here and in `terraform.tfstate`.** Save both to a password manager. If lost, delete the IAM access key and recreate it.

### 2.6 Confirm the SSM-managed EC2 is online

```bash
INSTANCE_ID=$(terraform output -raw ec2_instance_id)

aws ssm describe-instance-information \
  --region eu-west-3 \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query 'InstanceInformationList[0].{ID:InstanceId,Ping:PingStatus}' \
  --output table
```

Wait until `PingStatus` shows `Online`. If it stays `ConnectionLost` for more than 3 minutes:

```bash
ssh -i ~/.ssh/campuspulse-key.pem ec2-user@$(terraform output -raw api_public_ip) \
  "sudo systemctl restart amazon-ssm-agent"
```

---

## 3. Set Cognito user passwords

Terraform creates the two Cognito users in a `FORCE_CHANGE_PASSWORD` state. Their passwords must be set before they can log in.

```bash
cd ../..
POOL_ID=$(cd infra/terraform && terraform output -raw cognito_user_pool_id)
./scripts/bootstrap_cognito_users.sh "$POOL_ID"
```

Expected output:

```
✅ password set for staff1@campuspulse.local
✅ password set for student1@campuspulse.local

Login credentials:
  staff1@campuspulse.local   / Staff#2026Pass
  student1@campuspulse.local / Student#2026Pass
```

Verify both users are `CONFIRMED`:

```bash
aws cognito-idp admin-get-user \
  --user-pool-id "$POOL_ID" \
  --username staff1@campuspulse.local \
  --region eu-west-3 \
  --query 'UserStatus' --output text
```

Expected: `CONFIRMED`.

---

## 4. Local Python environment

### 4.1 Create the virtual environment

```bash
cd ~/Epita/CloudComputing/CampusPulse
python3.11 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install ruff==0.6.9 pre-commit
```

### 4.2 Get the values for `.env`

```bash
cd infra/terraform

echo "COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)"
echo "COGNITO_CLIENT_ID=$(terraform output -raw cognito_client_id)"
echo "SENSOR_API_KEY=$(grep sensor_api_key terraform.tfvars | cut -d'"' -f2)"

cd ../..
```

Note all three values.

### 4.3 Create `.env`

```bash
cat > .env <<'EOF'
APP_ENV=dev
AWS_REGION=eu-west-3
EVENTS_TABLE=campuspulse-events
USERS_TABLE=campuspulse-users
COGNITO_USER_POOL_ID=<paste from step 4.2>
COGNITO_CLIENT_ID=<paste from step 4.2>
COGNITO_REGION=eu-west-3
SENSOR_API_KEY=<paste from step 4.2>
LOG_GROUP=/campuspulse/api
EOF
```

Replace the three `<paste>` placeholders with the real values from step 4.2.

Verify:

```bash
grep -E "COGNITO_|SENSOR_" .env
```

You should see actual values, not placeholders.

### 4.4 Install pre-commit hooks

```bash
pre-commit install
```

Expected: `pre-commit installed at .git/hooks/pre-commit`.

### 4.5 Verify the app boots locally

```bash
source .venv/bin/activate
uvicorn app.main:app --reload
```

In another terminal:

```bash
curl -s http://localhost:8000/api/health
```

Expected: `{"status":"ok","env":"dev","region":"eu-west-3"}`

Test Cognito login against the real user pool:

```bash
curl -s -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"staff1@campuspulse.local","password":"Staff#2026Pass"}' \
  | python -m json.tool | head -5
```

Expected: a JSON response starting with `"access_token": "eyJ..."`.

Stop the local server (`Ctrl+C`).

---

## 5. Deploy backend

```bash
./scripts/deploy_app.sh
```

The script SSHes to the EC2 (resolved from Terraform state), pulls the latest `main`, installs Python dependencies into the EC2's virtualenv, refreshes secrets from SSM, restarts the `campuspulse` systemd service, and runs a health check.

Expected tail:

```
✅  Deploy successful on ip-10-42-1-XXX
✅  Local trigger complete.
```

Verify:

```bash
API_URL=$(cd infra/terraform && terraform output -raw api_url)
curl -m 5 "$API_URL/api/health"
```

Expected: `{"status":"ok","env":"prod","region":"eu-west-3"}`

---

## 6. Deploy frontend

```bash
./scripts/deploy_frontend.sh
```

The script builds the SPA, syncs `dashboard/dist/` to the S3 bucket, and creates a CloudFront invalidation for `/`, `/index.html`, `/assets/*`.

Expected tail:

```
✅  Frontend deployed.
    URL: https://dxxxxxxxxxxxxx.cloudfront.net
```

Verify:

```bash
CF_URL=$(cd infra/terraform && terraform output -raw cloudfront_url)
curl -s -o /dev/null -w "GET / -> %{http_code}\n" "$CF_URL/"
curl -s "$CF_URL/api/health"
```

Expected:

```
GET / -> 200
{"status":"ok","env":"prod","region":"eu-west-3"}
```

Open `$CF_URL` in a browser. Sign in as `staff1@campuspulse.local` / `Staff#2026Pass`.

---

## 7. Send simulated events

```bash
export SENSOR_API_KEY=$(grep sensor_api_key infra/terraform/terraform.tfvars | cut -d'"' -f2)
CF_URL=$(cd infra/terraform && terraform output -raw cloudfront_url)

python -m simulator.generate_events --count 30 --url "$CF_URL/api/events"
```

Expected: 30 lines, each starting with `[OK 201]`.

Verify persistence in DynamoDB:

```bash
aws dynamodb scan \
  --table-name campuspulse-events \
  --region eu-west-3 \
  --max-items 5 \
  --query 'Items[].{id:event_id.S,building:building.S,value:value.N}'
```

---

## 8. Frontend dev mode (optional)

```bash
cd dashboard
npm install
npm run dev
```

Open `http://localhost:5173`. The Vite dev server proxies `/api/*` to the EC2 backend (configured in `dashboard/vite.config.ts`).

---

## 9. Run the test suite

```bash
source .venv/bin/activate
pytest -v
```

Expected: 5 tests passing.

Smoke tests:

```bash
export SENSOR_API_KEY=$(grep sensor_api_key infra/terraform/terraform.tfvars | cut -d'"' -f2)
./scripts/test_cognito.sh
./scripts/test_alert.sh
```

---

## 10. Lint and format

```bash
# Python
ruff check app/ tests/ simulator/
ruff format --check app/ tests/ simulator/

# Terraform
cd infra/terraform && terraform fmt -check -recursive && cd ../..

# Frontend
cd dashboard
npm run format:check
npm run lint
cd ..
```

Auto-fix:

```bash
ruff check --fix app/ tests/ simulator/
ruff format app/ tests/ simulator/
cd dashboard && npm run format && cd ..
```

Run all pre-commit hooks:

```bash
pre-commit run --all-files
```

---

## 11. GitHub Actions CI/CD setup

### 11.1 Retrieve the credential values

```bash
cd infra/terraform

echo "AWS_ACCESS_KEY_ID: $(terraform output -raw gha_deployer_access_key_id)"
echo "AWS_SECRET_ACCESS_KEY: $(terraform output -raw gha_deployer_secret_access_key)"
echo "FRONTEND_BUCKET: $(terraform output -raw frontend_bucket)"
echo "CLOUDFRONT_DISTRIBUTION_ID: $(terraform output -raw cloudfront_distribution_id)"

cd ../..
```

Note the four values.

### 11.2 Add repository secrets

In your GitHub repository:

1. Open **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Create these four secrets one at a time:

| Name | Value from step 11.1 |
|---|---|
| `AWS_ACCESS_KEY_ID` | `gha_deployer_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | `gha_deployer_secret_access_key` |
| `FRONTEND_BUCKET` | `frontend_bucket` |
| `CLOUDFRONT_DISTRIBUTION_ID` | `cloudfront_distribution_id` |

**Do not** create an `EC2_INSTANCE_ID` secret. The workflow resolves the current EC2 instance ID at runtime from SSM Parameter Store, so it self-heals when the EC2 is replaced.

### 11.3 Workflows

Two workflow files exist in `.github/workflows/`:

| File | Trigger | Jobs |
|---|---|---|
| `ci.yml` | Push and pull requests on `main` | `lint` (ruff, terraform fmt, prettier, eslint), `test` (pytest) |
| `deploy.yml` | Push to `main` only | `deploy-backend` (SSM Run Command), `deploy-frontend` (S3 sync + CloudFront invalidation) |

No further configuration is needed. Push any commit to `main` to trigger both workflows.

View runs at:

```
https://github.com/<your-username>/CampusPulse/actions
```

Expected: both workflows complete with a green check.

---

## 12. Branch protection

In your GitHub repository:

1. Open **Settings → Rules → Rulesets**
2. Click **New branch ruleset**
3. **Ruleset Name:** `Protect main`
4. **Enforcement status:** `Active`
5. **Target branches:** click **Add target → Include by pattern**, enter `main`
6. Under **Branch rules**, enable:

| Rule | Setting |
|---|---|
| Restrict deletions | ✅ |
| Require a pull request before merging | ✅ Required approvals: `1`<br>✅ Dismiss stale pull request approvals when new commits are pushed<br>✅ Require approval of the most recent reviewable push<br>✅ Require conversation resolution before merging |
| Require status checks to pass | ✅ Add these checks:<br>• `Lint (ruff + terraform + prettier + eslint)`<br>• `Backend tests (pytest)`<br>✅ Require branches to be up to date before merging |
| Block force pushes | ✅ |
| Require linear history | ✅ |

7. Leave **Bypass list** empty
8. Click **Create**

Verify by attempting a direct push to `main`:

```bash
git checkout main
git commit --allow-empty -m "test: branch protection"
git push origin main
```

Expected: `! [remote rejected] main -> main (protected branch hook declined)`

Reset:

```bash
git reset --hard origin/main
```

---

## 13. Common operations

### Redeploy backend only

```bash
./scripts/deploy_app.sh
```

### Redeploy frontend only

```bash
./scripts/deploy_frontend.sh
```

### Stop the EC2 (cost discipline)

```bash
./scripts/ec2.sh stop
./scripts/ec2.sh start
./scripts/ec2.sh status
```

The Elastic IP and CloudFront URL do not change across stop/start.

### Rotate the sensor API key

```bash
# 1. Generate a new key
openssl rand -hex 24

# 2. Update infra/terraform/terraform.tfvars with the new value

# 3. Push to SSM
cd infra/terraform
terraform apply -target=aws_ssm_parameter.sensor_api_key -auto-approve
cd ..

# 4. Refresh the EC2 environment from SSM
./scripts/deploy_app.sh

# 5. Update your local shell exports
export SENSOR_API_KEY=<new value>
```

### Rebuild the EC2 (after editing `user_data.sh.tpl`)

```bash
cd infra/terraform
terraform apply -replace=aws_instance.api -auto-approve

# Clear the stale SSH host key
ssh-keygen -R "$(terraform output -raw api_public_ip)"
cd ..
```

Wait 90 seconds for cloud-init, then run `./scripts/deploy_app.sh`.

### View CloudWatch logs

```bash
STREAM=$(aws logs describe-log-streams \
  --log-group-name /campuspulse/api \
  --region eu-west-3 \
  --order-by LastEventTime --descending \
  --query 'logStreams[0].logStreamName' --output text)

aws logs get-log-events \
  --log-group-name /campuspulse/api \
  --log-stream-name "$STREAM" \
  --region eu-west-3 \
  --limit 20 \
  --query 'events[].message' \
  --output text
```

### View the CloudWatch dashboard

```
https://eu-west-3.console.aws.amazon.com/cloudwatch/home?region=eu-west-3#dashboards:name=campuspulse-ops
```

### View SSM parameters

```bash
aws ssm describe-parameters \
  --region eu-west-3 \
  --query 'Parameters[?starts_with(Name, `/campuspulse/`)].{Name:Name,Type:Type}' \
  --output table
```

---

## API endpoints

Base URL: `https://<cloudfront-domain>/api`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/auth/login` | none | Cognito login → JWT |
| GET | `/api/auth/me` | JWT | Current user's claims |
| POST | `/api/events` | staff JWT or `X-Sensor-Api-Key` | Ingest an event |
| GET | `/api/events` | JWT | List events (`building`, `event_type`, `severity`, `limit`) |
| GET | `/api/stats` | JWT | Per-building aggregates |
| GET | `/api/alerts` | staff JWT | Server-evaluated alerts (`building`, `severity`) |
| GET | `/api/health` | none | Liveness probe |

### Roles

| Group | Capabilities |
|---|---|
| `staff` | Read everything, write events, view alerts |
| `student` | Read events and stats only |

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

---

## AWS resources provisioned

| Layer | Service | Purpose |
|---|---|---|
| Compute | EC2 `t3.micro` | FastAPI + Uvicorn, systemd-managed |
| Networking | Elastic IP | Stable public endpoint |
| CDN | CloudFront | HTTPS, SPA hosting, `/api/*` proxy |
| Storage | S3 | SPA static assets |
| Database | DynamoDB | `campuspulse-events`, `campuspulse-users` |
| Auth | Cognito | User pool, app client, `staff` / `student` groups |
| Secrets | SSM Parameter Store | Sensor API key, Cognito IDs (KMS encrypted) |
| Logs | CloudWatch Logs | `/campuspulse/api` log group |
| Metrics | CloudWatch | `Api5xxCount`, `Api4xxCount`, `AWS/EC2` |
| Alarms | CloudWatch | `campuspulse-api-5xx-high` |
| Dashboard | CloudWatch | `campuspulse-ops` |
| IAM | IAM | EC2 role, GitHub Actions deployer user |
| CI/CD | GitHub Actions | `ci.yml`, `deploy.yml` |

---

## Teardown

```bash
cd infra/terraform
terraform apply -destroy -auto-approve
```
