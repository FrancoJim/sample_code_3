#!/usr/bin/env bash
# Build the Node.js app Docker image from the repo root and optionally push to a registry.
#
# What this image contains (see Dockerfile):
#   - Context is the repository root (.)
#   - chainsaw_jugglers/package*.json copied first, then npm ci --omit=dev
#   - Application code from chainsaw_jugglers/ (Express app, public/)
#   - Listens on PORT (default 8080 in the image)
#
# Prerequisites:
#   - Docker CLI and a running daemon (Docker Desktop, Colima, etc.)
#   - For --push: docker login credentials for the registry host in IMAGE
#       e.g. GHCR: set GHCR_USERNAME and GHCR_TOKEN (or GITHUB_TOKEN + GITHUB_ACTOR in Actions)
#
# Environment (optional):
#   IMAGE       Full image reference (default: ghcr.io/francojim/sample_code_3:latest)
#   DOCKERFILE  Path relative to repo root (default: Dockerfile)
#   CONTEXT     Build context path relative to repo root (default: .)
#
# Usage:
#   ./scripts/build_and_push.sh           # build only, tag IMAGE locally
#   ./scripts/build_and_push.sh --push    # build then docker push IMAGE
set -eu
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IMAGE="${IMAGE:-ghcr.io/francojim/sample_code_3:latest}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CONTEXT="${CONTEXT:-.}"

usage() {
  cat <<'EOF'
Usage: scripts/build_and_push.sh [--push]

  (default)  docker build -t $IMAGE -f $DOCKERFILE $CONTEXT
  --push     After build, docker login (when needed) and docker push $IMAGE

Environment: IMAGE, DOCKERFILE, CONTEXT, GHCR_USERNAME, GHCR_TOKEN (or GITHUB_TOKEN).
EOF
}

PUSH=false
for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
    --push)
      PUSH=true
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

registry_from_image() {
  # Strip tag or digest; first path segment before / is registry if it contains a dot or localhost
  local ref="$1"
  local host="${ref%%/*}"
  if [[ "$host" == *.* ]] || [[ "$host" == "localhost"* ]]; then
    echo "$host"
    return
  fi
  echo ""
}

login_if_ghcr() {
  local reg
  reg="$(registry_from_image "$IMAGE")"
  if [ "$reg" != "ghcr.io" ]; then
    return 0
  fi

  local user="${GHCR_USERNAME:-}"
  local token="${GHCR_TOKEN:-${GITHUB_TOKEN:-}}"
  if [ -z "$user" ] && [ -n "${GITHUB_ACTOR:-}" ]; then
    user="$GITHUB_ACTOR"
  fi

  if [ -z "$user" ] || [ -z "$token" ]; then
    echo "For ghcr.io push, set GHCR_USERNAME and GHCR_TOKEN (or GITHUB_TOKEN and GITHUB_ACTOR)." >&2
    exit 1
  fi

  echo "$token" | docker login ghcr.io -u "$user" --password-stdin
}

echo "Building ${IMAGE} (Dockerfile=${DOCKERFILE}, context=${CONTEXT})..."
docker build -f "$DOCKERFILE" -t "$IMAGE" "$CONTEXT"

if [ "$PUSH" != true ]; then
  echo "Build finished (local tag only). Use --push to publish."
  exit 0
fi

echo "Pushing ${IMAGE}..."
login_if_ghcr
docker push "$IMAGE"
echo "Push finished."
