#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/opt/multica}"
REPO_URL="${REPO_URL:-https://github.com/dimkk/multica.git}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"

if [[ ! -d "$DEPLOY_PATH/.git" ]]; then
  git clone "$REPO_URL" "$DEPLOY_PATH"
fi

cd "$DEPLOY_PATH"

if [[ ! -f .env ]]; then
  echo "Missing $DEPLOY_PATH/.env. Run scripts/deploy/bootstrap-ubuntu.sh first." >&2
  exit 1
fi

git fetch origin "$DEPLOY_BRANCH" --depth=1
git checkout "$DEPLOY_BRANCH"

if [[ -n "${GITHUB_SHA:-}" ]]; then
  git reset --hard "$GITHUB_SHA"
else
  git reset --hard "origin/${DEPLOY_BRANCH}"
fi

set -a
source ./.env
set +a

docker compose -f docker-compose.selfhost.yml up -d --build --remove-orphans
curl -fsS "http://127.0.0.1:${PORT:-8080}/health"
