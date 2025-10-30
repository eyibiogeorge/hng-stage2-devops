#!/bin/bash
set -euo pipefail

# --- Configuration & Logging ---

LOG_FILE="deploy_stage2_$(date +%Y%m%d_%H%M%S).log"
# Redirect stdout and stderr to both the console and the log file
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Source environment variables
source .env

# Determine Docker Compose command flavor
COMPOSE_CMD="docker-compose"
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
fi

# --- Helper Functions ---

wait_for_container() {
    local service=$1
    echo "⏳ Waiting for $service to be running..."
    for i in {1..15}; do # Increased attempts for robustness
        # Check for service in 'running' state and not 'exited'
        status=$($COMPOSE_CMD ps --status=running --services | grep -w "$service" || true)
        if [[ "$status" == "$service" ]]; then
            echo "✅ $service is running."
            return 0
        fi
        sleep 2
    done
    echo "❌ $service did not start/stay running in time. Checking logs..."
    $COMPOSE_CMD logs "$service" || true
    return 1
}

deploy_green() {
    echo "⚠️ ERROR: Attempting failover to GREEN deployment..."

    # Use a temporary .env to set the failover pool
    cat .env | sed 's/^ACTIVE_POOL=.*/ACTIVE_POOL=green/' > .env.failover

    # We must explicitly set RELEASE_ID to match the new pool for immediate Nginx restart
    ACTIVE_POOL="green"
    RELEASE_ID="$RELEASE_ID_GREEN"

    echo "🔁 Restarting Nginx with updated environment..."
    # Down/Up to ensure Nginx picks up the environment changes
    $COMPOSE_CMD stop nginx
    $COMPOSE_CMD up -d nginx

    wait_for_container nginx || { echo "❌ Failed to bring up Nginx on green pool."; exit 1; }
    
    # Restore original .env file (optional, but clean)
    mv .env.failover .env || true
    echo "✅ Failover to green complete. New ACTIVE_POOL is $ACTIVE_POOL."
}

cleanup() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "❌ SCRIPT FAILED: Line $1 exited with status $exit_code"
        deploy_green
        exit "$exit_code"
    fi
}
# Trap for any command failure (ERR)
trap 'cleanup $LINENO' ERR

# --- Main Deployment Logic ---

echo "🔍 Checking required files..."
for f in docker-compose.yml config/nginx.conf.template .env; do
    [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done

# Ensure environment is set for the initial pull and start
if [[ "$ACTIVE_POOL" == "blue" ]]; then
    export RELEASE_ID="$RELEASE_ID_BLUE"
else
    export RELEASE_ID="$RELEASE_ID_GREEN"
fi

echo "📦 Pulling Docker images..."
docker pull "$BLUE_IMAGE"
docker pull "$GREEN_IMAGE"

echo "🚀 Starting services (Active Pool: $ACTIVE_POOL)..."
$COMPOSE_CMD down -v --remove-orphans # Added --remove-orphans
$COMPOSE_CMD up -d

# Wait for application containers to be available before Nginx
wait_for_container app_blue
wait_for_container app_green

# Nginx should now be able to start and proxy
wait_for_container nginx

echo "🔎 Validating deployment..."
sleep 10 # Increased sleep for more reliable application startup
response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/version")

if [[ "$response" != "200" ]]; then
    echo "❌ Validation failed with status $response"
    echo "Nginx/Application logs:"
    $COMPOSE_CMD logs nginx app_blue || true
    # This will trigger the ERR trap and call cleanup/deploy_green
    false
fi

echo "✅ Deployment successful. ACTIVE_POOL=$ACTIVE_POOL"