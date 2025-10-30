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

# Set initial release ID based on active pool
if [[ "$ACTIVE_POOL" == "blue" ]]; then
  export RELEASE_ID="$RELEASE_ID_BLUE"
else
  export RELEASE_ID="$RELEASE_ID_GREEN"
fi

wait_for_container() {
  local service=$1
  echo "⏳ Waiting for $service to be running..."
  for i in {1..10}; do
    status=$($COMPOSE_CMD ps --status=running --services | grep -w "$service" || true)
    if [[ "$status" == "$service" ]]; then
      echo "✅ $service is running."
      return 0
    fi
    sleep 2
  done
  echo "❌ $service did not start in time."
  return 1
}

deploy_green() {
  echo "⚠️ Switching to green deployment..."
  export ACTIVE_POOL="green"
  export RELEASE_ID="$RELEASE_ID_GREEN"

  echo "🔁 Restarting Nginx with updated environment..."
  $COMPOSE_CMD stop nginx
  $COMPOSE_CMD up -d nginx
  wait_for_container nginx

  echo "✅ Failover to green complete."
}

cleanup() {
  echo "❌ ERROR: Script failed at line $1 with status $2"
  if [[ "${MAINTENANCE_MODE:-false}" == "true" ]]; then
    echo "🛠️ Maintenance mode enabled — suppressing alerts."
  else
    echo "🔔 Alert: Failover triggered due to deployment failure."
    # Optional: send Slack alert here using curl + SLACK_WEBHOOK_URL
  fi
  deploy_green
  exit "$2"
}
trap 'cleanup $LINENO $?' ERR

echo "🔍 Checking required files..."
for f in docker-compose.yml config/nginx.conf.template .env; do
  [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done

echo "📦 Pulling Docker images..."
docker pull "$BLUE_IMAGE"
docker pull "$GREEN_IMAGE"

echo "🚀 Starting services..."
$COMPOSE_CMD down -v
$COMPOSE_CMD up -d
wait_for_container nginx

echo "🔎 Validating deployment..."
sleep 5
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/version)

if [[ "$response" != "200" ]]; then
  echo "❌ Validation failed with status $response"
  false
fi

echo "✅ Deployment successful. ACTIVE_POOL=$ACTIVE_POOL"