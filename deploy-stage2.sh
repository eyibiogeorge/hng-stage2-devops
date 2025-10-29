#!/bin/bash

# Set strict mode
set -euo pipefail

# Initialize logging
LOG_FILE="deploy_stage2_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Trap errors
cleanup() {
    echo "ERROR: Script failed at line $1 with status $2" >&2
    echo "Dumping container logs for debugging..."
    $COMPOSE_CMD logs nginx
    $COMPOSE_CMD logs app_blue
    $COMPOSE_CMD logs app_green
    echo "Checking Nginx configuration..."
    $COMPOSE_CMD exec -T nginx cat /tmp/nginx_config.log || echo "No Nginx config log available"
    $COMPOSE_CMD exec -T nginx cat /tmp/nginx_config_error.log || echo "No Nginx config error log available"
    exit "$2"
}
trap 'cleanup $LINENO $?' ERR

# Check for required files
echo "Checking for required files..."
for file in docker-compose.yml config/nginx.conf.template .env; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: $file not found in current directory"
        exit 1
    fi
done

# Verify .env variables
echo "Checking .env variables..."
source .env
for var in BLUE_IMAGE GREEN_IMAGE ACTIVE_POOL RELEASE_ID_BLUE RELEASE_ID_GREEN; do
    if [[ -z "${!var}" ]]; then
        echo "ERROR: $var is not set in .env"
        exit 1
    fi
done
if [[ "$ACTIVE_POOL" != "blue" && "$ACTIVE_POOL" != "green" ]]; then
    echo "ERROR: ACTIVE_POOL must be 'blue' or 'green'"
    exit 1
fi

# Check port availability
echo "Checking port availability..."
PORT=${PORT:-8080}
if command -v ss >/dev/null; then
    if ss -tuln | grep -q ":$PORT "; then
        echo "ERROR: Port $PORT is in use"
        exit 1
    fi
elif command -v netstat >/dev/null; then
    if netstat -tuln | grep -q ":$PORT "; then
        echo "ERROR: Port $PORT is in use"
        exit 1
    fi
else
    echo "WARNING: Neither ss nor netstat found, skipping port check"
fi

# Pull images to ensure they are available
echo "Pulling Docker images..."
docker pull "$BLUE_IMAGE"
docker pull "$GREEN_IMAGE"

# Use docker compose if available, otherwise fallback to docker-compose
COMPOSE_CMD="docker-compose"
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
fi
echo "Using compose command: $COMPOSE_CMD"

# Run Docker Compose
echo "Starting Docker Compose..."
$COMPOSE_CMD up -d

# Validate deployment
echo "Validating deployment..."
sleep 15
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT:-8080}/version || echo "failed")
if [[ "$response" != "200" ]]; then
    echo "ERROR: Failed to get 200 response from http://localhost:${PORT:-8080}/version (got $response)"
    $COMPOSE_CMD logs nginx
    $COMPOSE_CMD logs app_blue
    $COMPOSE_CMD logs app_green
    $COMPOSE_CMD exec -T nginx cat /tmp/nginx_config.log || echo "No Nginx config log available"
    $COMPOSE_CMD exec -T nginx cat /tmp/nginx_config_error.log || echo "No Nginx config error log available"
    exit 1
fi

# Verify headers
echo "Verifying response headers..."
headers=$(curl -s -I http://localhost:${PORT:-8080}/version)
if ! echo "$headers" | grep -q "X-App-Pool: ${ACTIVE_POOL}"; then
    echo "ERROR: X-App-Pool header does not match ACTIVE_POOL (${ACTIVE_POOL})"
    echo "Headers received:"
    echo "$headers"
    exit 1
fi
if ! echo "$headers" | grep -q "X-Release-Id: ${RELEASE_ID_${ACTIVE_POOL^^}}"; then
    echo "ERROR: X-Release-Id header does not match expected value (${RELEASE_ID_${ACTIVE_POOL^^}})"
    echo "Headers received:"
    echo "$headers"
    exit 1
fi

# Test direct access to app_blue and app_green
echo "Testing direct access to app_blue and app_green..."
for service in blue green; do
    port_var="PORT_${service^^}"
    port=${!port_var:-${service == "blue" && echo 8081 || echo 8082}}
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/version || echo "failed")
    if [[ "$response" != "200" ]]; then
        echo "WARNING: Failed to get 200 response from http://localhost:$port/version for app_$service (got $response)"
    else
        echo "Successfully accessed http://localhost:$port/version for app_$service"
    fi
done

echo "Deployment successful. Logs saved to $LOG_FILE"
echo "Test with: curl -v http://localhost:${PORT:-8080}/version"