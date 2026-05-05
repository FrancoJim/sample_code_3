# sample_code_3 — GCP production deployment demo

> **Portfolio project.** The application is a fictional business (Timberline Toss Academy, a chainsaw juggling school) used as a realistic deployment target. The point of the repo is the infrastructure and delivery pipeline, not the app itself.

---

## What this demonstrates

| Skill | Implementation |
| ----- | -------------- |
| Containerisation | Node 20 on `node:20-bookworm-slim`, production deps only, non-root user, `HEALTHCHECK` |
| Google Cloud infrastructure | Cloud Run v2 · global external HTTPS LB · Cloud Armor geo policy · Certificate Manager TLS · Cloudflare DNS |
| Terraform | Modular `.tf` files per resource group, `variables.tf` / `outputs.tf`, GCS-ready remote state |
| CI/CD — keyless auth | GitHub Actions with **Workload Identity Federation** — no long-lived SA keys stored as secrets |
| CI/CD — change gating | `dorny/paths-filter` skips build/deploy when neither app code nor `Dockerfile` changed |
| Devcontainer | Ubuntu 24.04 workspace with every CLI tool pre-installed; local Docker registry sidecar |

---

## Architecture

```
Browser
  └─► Cloudflare DNS (A record → LB IP)
        └─► GCP Global External HTTPS Load Balancer  (Certificate Manager TLS)
              └─► Cloud Armor backend security policy  (geo allow-list; deny 403 elsewhere)
                    └─► Serverless NEG
                          └─► Cloud Run v2 service  (internal-LB ingress only)
                                └─► Container: node:20-bookworm-slim, port 8080
```

---

## Repository layout

```
.
├── .devcontainer/          Ubuntu workspace + local registry (see Devcontainer section)
├── .github/workflows/
│   └── build-deploy.yml    build → push → Terraform deploy (workflow_dispatch)
├── chainsaw_jugglers/      Express app: app.js, public/, package.json
├── scripts/
│   ├── build_and_push.sh   docker build / push to GHCR (or any registry)
│   ├── runner.sh           terraform init / plan / apply / deploy + health checks
│   └── runner_dev.sh       docker compose up --build (local dev shortcut)
├── terraform/              GCP infra — Cloud Run, LB, Armor, certs, Cloudflare DNS
├── docker-compose.yml      Run the app locally (127.0.0.1:8081 → container 8080)
├── Dockerfile              Production container image
└── example.env             Required env vars checklist
```

---

## Run locally

### Node (no Docker)

```bash
cd chainsaw_jugglers
npm ci
npm start          # http://localhost:8080
```

### Docker Compose

```bash
docker compose -f docker-compose.yml up --build
# or
./scripts/runner_dev.sh
```

Open **http://127.0.0.1:8081** (the container still listens on 8080; 8081 is the host port to avoid conflicts).

---

## Build and push the container image

```bash
./scripts/build_and_push.sh          # local tag only

# Push to GHCR:
export IMAGE=ghcr.io/francojim/sample_code_3:latest
export GHCR_USERNAME=your_github_username
export GHCR_TOKEN=your_token_with_write_packages
./scripts/build_and_push.sh --push
```

In GitHub Actions, `GITHUB_TOKEN` and `github.actor` fill `GHCR_TOKEN` / `GHCR_USERNAME` automatically.

---

## Terraform — Google Cloud + optional Cloudflare

### Resource overview

| File | What it manages |
| ---- | --------------- |
| `gcs_project_apis.tf` | Enables Compute Engine, Cloud Run, Certificate Manager APIs |
| `gcs_cloud_run.tf` | Cloud Run v2 service — internal-LB ingress, min 0 / max 10 instances |
| `gcs_load_balancer_edge.tf` | Global external HTTPS LB, static IP, HTTP→HTTPS redirect |
| `gcs_load_balancer_backend.tf` | Serverless NEG backend, forwarding rule |
| `gcs_certificates_public.tf` | Certificate Manager map + DNS-validated cert for `var.domain` |
| `gcs_cloud_armor.tf` | Geo allow-list policy (US, CA, and configurable EU set) |
| `cloudflare_dns_records.tf` | Optional A record — enabled by `manage_cloudflare_dns = true` |
| `variables.tf` | `project_id`, `region`, `domain`, `docker_image`, `cloud_run_service_name`, Cloudflare toggles |
| `outputs.tf` | `load_balancer_ip`, `dns_authorization_records`, `cloud_run_service`, `certificate_map_uri` |

### Apply by hand

```bash
# Authenticate (pick one):
gcloud auth application-default login
# — or —
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

# Optional: create terraform/terraform.tfvars with project_id, region, docker_image, etc.

cd terraform
terraform init
terraform plan
terraform apply
```

See `example.env` for the full variable checklist.

### Deploy via `scripts/runner.sh`

| Command | Behaviour |
| ------- | --------- |
| `init` | `terraform init -input=false` |
| `plan` | init → `terraform plan -input=false` |
| `apply` | init → `terraform apply -input=false` |
| `deploy` | init → apply → wait for Cloud Run Ready → HTTPS probe via LB IP |

```bash
export TF_VAR_project_id=YOUR_GCP_PROJECT_ID
export GCP_PROJECT_ID=YOUR_GCP_PROJECT_ID
./scripts/runner.sh deploy
```

---

## GitHub Actions

**Workflow:** `.github/workflows/build-deploy.yml` — trigger: `workflow_dispatch`.

### Keyless GCP auth (Workload Identity Federation)

The deploy job exchanges the GitHub Actions OIDC token for short-lived GCP credentials via Workload Identity Federation. **No `GCP_SA_KEY` secret is stored in the repo.**

One-time setup:

```bash
# 1. Create the WIF pool and OIDC provider
gcloud iam workload-identity-pools create "github-actions" \
  --project="${GCP_PROJECT_ID}" --location="global"

gcloud iam workload-identity-pools providers create-oidc "github" \
  --project="${GCP_PROJECT_ID}" --location="global" \
  --workload-identity-pool="github-actions" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# 2. Bind the SA to this repo only
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${GCP_PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_RESOURCE_NAME}/attribute.repository/francojim/sample_code_3"
```

Then set three repository secrets (no JSON key):

| Secret | Value |
| ------ | ----- |
| `GCP_PROJECT_ID` | GCP project ID |
| `GCP_WIF_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/providers/github` |
| `GCP_SERVICE_ACCOUNT` | `deploy-sa@PROJECT_ID.iam.gserviceaccount.com` |

### Job summary

| Job | Condition | What runs |
| --- | --------- | --------- |
| `changes` | always | `dorny/paths-filter` — sets `code=true` if `chainsaw_jugglers/**` or `Dockerfile` changed |
| `build-and-push` | `code == true` | `scripts/build_and_push.sh --push` → GHCR |
| `deploy` | `code == true` | WIF auth → `scripts/runner.sh deploy` with `TF_VAR_*` from workflow env / secrets |

---

## Devcontainer

Opens a fully-configured Ubuntu 24.04 workspace in Cursor or VS Code. All tools are pre-installed in the image — nothing to install manually after opening.

### What's in the image

| Tool | Version |
| ---- | ------- |
| Node.js | 20 LTS |
| Python | 3.x (system) + pip |
| Ansible | latest via pip |
| Terraform | latest from HashiCorp apt |
| gcloud CLI | latest from Google apt |
| Docker CLI + Buildx + Compose plugin | latest from Docker apt |
| kubectl | v1.31 |
| Helm | 3.16.3 |

### Services (`.devcontainer/docker-compose.yml`)

| Service | Purpose |
| ------- | ------- |
| `devcontainer` | Workspace — mounts repo at `/workspace`, Docker socket at `/var/run/docker.sock` |
| `registry` | Local Docker registry — push/pull at `registry:5000` (inside) or `localhost:5050` (host, avoids macOS AirPlay conflict on 5000) |

### Shell prompt

```
sample_code_3 | master | /workspace $
```

Cyan repo · yellow branch · green path. Shows a short SHA on detached HEAD; dashes outside a git repo.

### Opening

Open the repo folder in Cursor or VS Code and accept the **Reopen in Container** prompt. On first open the image builds (5–10 min); subsequent opens are instant from cache.

To run the app inside the devcontainer:

```bash
# Build and start from inside the workspace:
docker compose -f /workspace/docker-compose.yml up --build

# Or push to the local registry first:
docker build -t registry:5000/sample_code_3:dev .
docker push registry:5000/sample_code_3:dev
```

---

## References

- [Cloud Run v2](https://cloud.google.com/run/docs)
- [External HTTPS load balancing](https://cloud.google.com/load-balancing/docs/https)
- [Cloud Armor](https://cloud.google.com/armor/docs)
- [Certificate Manager](https://cloud.google.com/certificate-manager/docs)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Terraform Google provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform Cloudflare provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
