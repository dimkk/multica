#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/opt/multica}"
REPO_URL="${REPO_URL:-https://github.com/dimkk/multica.git}"
SERVER_IP="${SERVER_IP:-195.209.219.118}"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a regular sudo-capable user, not root." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y ca-certificates curl git make openssl

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
fi

sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker

if docker compose version >/dev/null 2>&1; then
  :
elif command -v docker-compose >/dev/null 2>&1; then
  :
else
  sudo apt-get install -y docker-compose-plugin
fi

sudo mkdir -p "$(dirname "$DEPLOY_PATH")"
sudo chown -R "$USER":"$USER" "$(dirname "$DEPLOY_PATH")"

if [[ ! -d "$DEPLOY_PATH/.git" ]]; then
  git clone "$REPO_URL" "$DEPLOY_PATH"
fi

cd "$DEPLOY_PATH"

if [[ ! -f .env ]]; then
  cp deploy/selfhost.server.env.example .env
  sed -i "s/replace-with-openssl-rand-hex-32/$(openssl rand -hex 32)/" .env
  sed -i "s|http://195.209.219.118|http://${SERVER_IP}|g" .env
  sed -i "s|ws://195.209.219.118|ws://${SERVER_IP}|g" .env
  echo "Created $DEPLOY_PATH/.env from deploy/selfhost.server.env.example"
  echo "Update POSTGRES_PASSWORD and any auth provider settings before exposing the server publicly."
fi

docker compose -f docker-compose.selfhost.yml up -d --build

set -a
source ./.env
set +a

curl -fsS "http://127.0.0.1:${PORT:-8080}/health"
echo
echo "Multica is running."
echo "Frontend: http://${SERVER_IP}:${FRONTEND_PORT:-3000}"
echo "Backend:  http://${SERVER_IP}:${PORT:-8080}"
