#!/bin/bash
set -euo pipefail

LOG_FILE="deploy_stage2_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

source .env

COMPOSE_CMD="docker-compose"
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
fi

deploy_green() {
  echo "Switching to green deployment..."
  export ACTIVE_POOL="green"
  envsubst < config/nginx.conf.template > config/nginx.conf
  $COMPOSE_CMD up -d app_green nginx
  echo "Failover to green complete."
}

cleanup() {
  echo "ERROR: Script failed at line $1 with status $2"
  deploy_green
  exit "$2"
}
trap 'cleanup $LINENO $?' ERR

echo "Checking required files..."
for f in docker-compose.yml config/nginx.conf.template .env; do
  [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done

echo "Pulling images..."
docker pull "$BLUE_IMAGE"
docker pull "$GREEN_IMAGE"

echo "Starting services..."
$COMPOSE_CMD up -d

echo "Validating deployment..."
sleep 10
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/version)

if [[ "$response" != "200" ]]; then
  echo "Validation failed with status $response"
  false  # triggers ERR trap
fi

echo "Deployment successful. ACTIVE_POOL=$ACTIVE_POOL"