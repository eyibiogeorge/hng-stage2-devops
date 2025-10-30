#!/bin/bash
set -euo pipefail

# Logging
LOG_FILE="deploy_stage2_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Load environment
source .env

# Compose command
COMPOSE_CMD="docker-compose"
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
fi

# Determine release ID
if [[ "$ACTIVE_POOL" == "blue" ]]; then
  export RELEASE_ID="$RELEASE_ID_BLUE"
else
  export RELEASE_ID="$RELEASE_ID_GREEN"
fi

# Wait for a container to be healthy or running
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

# Failover to green
deploy_green() {
  echo "⚠️ Switching to green deployment..."
  export ACTIVE_POOL="green"
  export RELEASE_ID="$RELEASE_ID_GREEN"

  # Restart nginx with updated env
  $COMPOSE_CMD up -d nginx
  wait_for_container nginx

  echo "🔁 Regenerating Nginx config..."
  $COMPOSE_CMD exec -T nginx /bin/sh -c "
    envsubst '\$ACTIVE_POOL \$BLUE_HOST \$BLUE_PORT \$GREEN_HOST \$GREEN_PORT \$RELEASE_ID' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf &&
    nginx -s reload || nginx
  "

  echo "✅ Failover to green complete."
}

# Error trap
cleanup() {
  echo "❌ ERROR: Script failed at line $1 with status $2"
  deploy_green
  exit "$2"
}
trap 'cleanup $LINENO $?' ERR

# Check required files
echo "🔍 Checking required files..."
for f in docker-compose.yml config/nginx.conf.template .env; do
  [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done

# Pull images
echo "📦 Pulling Docker images..."
docker pull "$BLUE_IMAGE"
docker pull "$GREEN_IMAGE"

# Start services
echo "🚀 Starting services..."
$COMPOSE_CMD up -d
wait_for_container nginx

# Validate deployment
echo "🔎 Validating deployment..."
sleep 5
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/version)

if [[ "$response" != "200" ]]; then
  echo "❌ Validation failed with status $response"
  false  # triggers cleanup
fi

echo "✅ Deployment successful. ACTIVE_POOL=$ACTIVE_POOL"