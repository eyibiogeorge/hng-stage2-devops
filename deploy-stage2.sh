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

# Set the initial RELEASE_ID based on ACTIVE_POOL for image pulling (no change needed here)
if [[ "$ACTIVE_POOL" == "blue" ]]; then
    export RELEASE_ID="$RELEASE_ID_BLUE"
else
    export RELEASE_ID="$RELEASE_ID_GREEN"
fi

# --- Helper Functions ---

wait_for_container() {
    local service=$1
    echo "⏳ Waiting for $service to be running..."
    # Increase checks from 10 to 15
    for i in {1..15}; do
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

    # Create a temporary .env file for Docker Compose to use 'green'
    cat .env | sed 's/^ACTIVE_POOL=.*/ACTIVE_POOL=green/' > .env.failover
    # Temporarily rename the active .env to allow Docker Compose to use the failover file
    mv .env .env.temp
    mv .env.failover .env

    # We must explicitly set variables for the script's reporting and logic
    ACTIVE_POOL="green"
    RELEASE_ID="$RELEASE_ID_GREEN"

    echo "🔁 Restarting Nginx with updated environment..."
    # Stop and start Nginx to pick up the new ACTIVE_POOL from the updated .env
    $COMPOSE_CMD stop nginx
    $COMPOSE_CMD up -d nginx

    wait_for_container nginx || { echo "❌ Failed to bring up Nginx on green pool."; exit 1; }
    
    # Restore original .env file (optional, but clean)
    mv .env .env.failover # Rename the current .env (which is green) to failover
    mv .env.temp .env # Restore the temp (which is the original, blue)

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

echo "📦 Pulling Docker images..."
docker pull "$BLUE_IMAGE"
docker pull "$GREEN_IMAGE"

echo "🚀 Starting services (Active Pool: $ACTIVE_POOL)..."
$COMPOSE_CMD down -v --remove-orphans
$COMPOSE_CMD up -d

# Wait for application containers to be available before Nginx
wait_for_container app_blue
wait_for_container app_green
wait_for_container nginx

echo "🚀 Waiting for all services to be stable (20s initial delay)..."
sleep 20 # Increased sleep to ensure application is ready to serve traffic

echo "🔎 Validating deployment..."
# Use curl flags for retries and timeouts for robust validation
response=$(curl -s --connect-timeout 5 --retry 15 --retry-delay 2 -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/version")
curl_exit_code=$?

if [[ "$curl_exit_code" -ne 0 ]]; then
    # Curl failed with a non-HTTP error (like status 7 for connection refused)
    echo "❌ Validation failed: Curl exit code $curl_exit_code (Connection Error)"
    echo "--- Nginx Logs ---"
    $COMPOSE_CMD logs nginx || true 
    echo "--- Application Logs (Active: $ACTIVE_POOL) ---"
    $COMPOSE_CMD logs app_"$ACTIVE_POOL" || true
    false # Trigger the ERR trap
elif [[ "$response" != "200" ]]; then
    # Curl succeeded but received a non-200 HTTP code (e.g., 502 or 404)
    echo "❌ Validation failed with HTTP status $response"
    echo "--- Nginx Logs ---"
    $COMPOSE_CMD logs nginx || true
    echo "--- Application Logs (Active: $ACTIVE_POOL) ---"
    $COMPOSE_CMD logs app_"$ACTIVE_POOL" || true
    false # Trigger the ERR trap
fi

echo "✅ Deployment successful. ACTIVE_POOL=$ACTIVE_POOL"