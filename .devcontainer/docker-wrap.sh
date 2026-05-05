#!/usr/bin/env bash
# Dev Containers invokes this instead of the real docker binary when
# "dockerPath" is set in devcontainer.json. Global COMPOSE_FILE / COMPOSE_PROJECT_NAME
# (often exported from multi-stack Docker setups) get merged with devcontainer compose
# files; if any listed path is missing, `docker compose` fails immediately with stat(2).
set -euo pipefail

# Resolve real Docker CLI without recursing into this script.
# OrbStack, Docker Desktop, and Colima all expose the same `docker` CLI shape; OrbStack
# often installs ~/.orbstack/bin/docker or symlinks /usr/local/bin/docker → OrbStack.app.
_REAL_DOCKER=""
for _c in /usr/local/bin/docker /opt/homebrew/bin/docker \
  "${HOME}/.orbstack/bin/docker" \
  "/Applications/Docker.app/Contents/Resources/bin/docker"; do
  if [ -x "$_c" ] && [ "$_c" != "${BASH_SOURCE[0]}" ]; then
    _REAL_DOCKER="$_c"
    break
  fi
done
if [ -z "$_REAL_DOCKER" ]; then
  _REAL_DOCKER=$(PATH="${HOME}/.orbstack/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin" command -v docker || true)
fi
if [ -z "$_REAL_DOCKER" ] || [ ! -x "$_REAL_DOCKER" ]; then
  echo "docker-wrap.sh: could not find real docker binary" >&2
  exit 127
fi

# Compose sub-commands must not inherit broken COMPOSE_FILE merge from the parent shell.
if [ "${1-}" = "compose" ]; then
  exec env -u COMPOSE_FILE -u COMPOSE_PATH_SEPARATOR -u COMPOSE_PROJECT_NAME "$_REAL_DOCKER" "$@"
fi
exec "$_REAL_DOCKER" "$@"
