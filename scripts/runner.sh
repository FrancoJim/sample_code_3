#!/usr/bin/env bash
# Terraform helper: init / plan / apply / full deploy (apply + Cloud Run wait + HTTPS probe).
set -eu
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_REL="${TF_DIR:-terraform}"
TF_ABS="$ROOT/$TF_REL"

GCP_REGION="${GCP_REGION:-us-east1}"
CLOUD_RUN_SERVICE="${CLOUD_RUN_SERVICE:-sample-code-3-web}"
PUBLIC_DOMAIN="${PUBLIC_DOMAIN:-sample3.francojim.com}"

usage() {
  cat <<'EOF'
Usage: scripts/runner.sh <command> [terraform-args...]

Commands:
  init    terraform init -input=false
  plan    terraform init && terraform plan -input=false
  apply   terraform init && terraform apply -input=false (pass flags such as -auto-approve after "apply")
  deploy  terraform init && terraform apply -input=false -auto-approve, then wait for Cloud Run Ready
          and curl the public hostname via the load balancer IP (terraform output).

Environment:
  TF_DIR               Terraform directory relative to repo root (default: terraform).
  TF_VAR_*             Standard Terraform variable env vars.
  GCP_PROJECT_ID       Required for deploy health checks (gcloud / jq).
  GCP_REGION           Default us-east1
  CLOUD_RUN_SERVICE    Default sample-code-3-web
  PUBLIC_DOMAIN        Default sample3.francojim.com
EOF
}

run_health_checks() {
  if [ -z "${GCP_PROJECT_ID:-}" ]; then
    if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
      echo "GCP_PROJECT_ID must be set in CI for deploy health checks." >&2
      exit 1
    fi
    echo "Warning: GCP_PROJECT_ID unset; skipping post-apply health checks." >&2
    return 0
  fi

  echo "Waiting for Cloud Run service ${CLOUD_RUN_SERVICE} (region ${GCP_REGION})..."
  for i in $(seq 1 36); do
    READY="$(gcloud run services describe "${CLOUD_RUN_SERVICE}" \
      --region="${GCP_REGION}" \
      --project="${GCP_PROJECT_ID}" \
      --format=json 2>/dev/null | jq -r '.status.conditions[]? | select(.type=="Ready") | .status' || true)"
    if [ "$READY" = "True" ]; then
      echo "Cloud Run reports Ready=True"
      break
    fi
    echo "Attempt ${i}: Ready=${READY:-unknown}"
    if [ "$i" -eq 36 ]; then
      echo "Timed out waiting for Cloud Run Ready" >&2
      exit 1
    fi
    sleep 10
  done

  LB_IP="$(terraform output -raw load_balancer_ip)"
  echo "Load balancer IP: ${LB_IP}"
  curl -fsS --max-time 30 \
    --resolve "${PUBLIC_DOMAIN}:443:${LB_IP}" \
    "https://${PUBLIC_DOMAIN}/" | head -c 400
  echo
  echo "HTTPS probe succeeded"
}

cmd="${1:-}"
if [ -z "$cmd" ] || [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ]; then
  usage
  exit "$([ -n "$cmd" ] && echo 0 || echo 1)"
fi

shift

cd "$TF_ABS"

case "$cmd" in
  init)
    terraform init -input=false "$@"
    ;;
  plan)
    terraform init -input=false
    terraform plan -input=false "$@"
    ;;
  apply)
    terraform init -input=false
    terraform apply -input=false "$@"
    ;;
  deploy)
    terraform init -input=false
    terraform apply -input=false -auto-approve "$@"
    run_health_checks
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    usage
    exit 1
    ;;
esac
