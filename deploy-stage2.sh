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
    echo "Validation response body:"
    cat /tmp/response_body.txt || echo "No response body available"
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
echo "Environment variables: ACTIVE_POOL=$ACTIVE_POOL, RELEASE_ID_BLUE=$RELEASE_ID_BLUE, RELEASE_ID_GREEN=$RELEASE_ID_GREEN"

# Check port availability
echo "Checking port availability..."
PORT=${PORT:-8080}
if command -v ss >/dev/null; then
    if ss -tuln | grep -q ":$PORT "; then
        echo "ERROR: Port $PORT is in use"
        echo "Processes using port $PORT:"
        ss -tulnp | grep ":$PORT" || echo "No process details available"
        echo "Attempting to stop existing Docker Compose services..."
        docker compose down || echo "Failed to stop Docker Compose services"
        if ss -tuln | grep -q ":$PORT "; then
            echo "ERROR: Port $PORT is still in use after attempting to stop services"
            echo "Try stopping the process manually with 'sudo fuser -k $PORT/tcp' or use a different port"
            exit 1
        fi
    fi
elif command -v netstat >/dev/null; then
    if netstat -tuln | grep -q ":$PORT "; then
        echo "ERROR: Port $PORT is in use"
        echo "Processes using port $PORT:"
        netstat -tulnp | grep ":$PORT" || echo "No process details available"
        echo "Attempting to stop existing Docker Compose services..."
        docker compose down || echo "Failed to stop Docker Compose services"
        if netstat -tuln | grep -q ":$PORT "; then
            echo "ERROR: Port $PORT is still in use after attempting to stop services"
            echo "Try stopping the process manually with 'sudo fuser -k $PORT/tcp' or use a different port"
            exit 1
        fi
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

# Reset chaos state to ensure clean deployment
echo "Resetting chaos state for app_blue and app_green..."
curl -s -X POST http://localhost:8081/chaos/stop || echo "Failed to reset chaos for app_blue"
curl -s -X POST http://localhost:8082/chaos/stop || echo "Failed to reset chaos for app_green"

# Validate deployment
echo "Validating deployment..."
sleep 15
curl -s -v http://localhost:${PORT:-8080}/version > /tmp/validation_output.txt 2>&1
response=$(grep "< HTTP/1.1" /tmp/validation_output.txt | awk '{print $3}' || echo "failed")
if [[ "$response" != "200" ]]; then
    echo "ERROR: Failed to get 200 response from http://localhost:${PORT:-8080}/version (got $response)"
    echo "Full curl output:"
    cat /tmp/validation_output.txt
    $COMPOSE_CMD logs nginx
    $COMPOSE_CMD logs app_blue
    $COMPOSE_CMD logs app_green
    $COMPOSE_CMD exec -T nginx cat /tmp/nginx_config.log || echo "No Nginx config log available"
    $COMPOSE_CMD exec -T nginx cat /tmp/nginx_config_error.log || echo "No Nginx config error log available"
    exit 1
fi

# Verify headers
echo "Verifying response headers..."
headers=$(grep "^<" /tmp/validation_output.txt)
if ! echo "$headers" | grep -q "X-App-Pool: ${ACTIVE_POOL}"; then
    echo "ERROR: X-App-Pool header does not match ACTIVE_POOL (${ACTIVE_POOL})"
    echo "Headers received:"
    echo "$headers"
    exit 1
fi
if [[ "$ACTIVE_POOL" == "blue" ]]; then
    EXPECTED_RELEASE_ID="$RELEASE_ID_BLUE"
else
    EXPECTED_RELEASE_ID="$RELEASE_ID_GREEN"
fi
if ! echo "$headers" | grep -q "X-Release-Id: ${EXPECTED_RELEASE_ID}"; then
    echo "ERROR: X-Release-Id header does not match expected value (${EXPECTED_RELEASE_ID})"
    echo "Headers received:"
    echo "$headers"
    exit 1
fi

# Test direct access to app_blue and app_green
echo "Testing direct access to app_blue and app_green..."
for service in blue green; do
    port_var="PORT_${service^^}"
    port=${!port_var:-${service == "blue" && echo 8081 || echo 8082}}
    curl -s -v http://localhost:$port/version > /tmp/response_output_${service}.txt 2>&1
    response=$(grep "< HTTP/1.1" /tmp/response_output_${service}.txt | awk '{print $3}' || echo "failed")
    if [[ "$response" != "200" ]]; then
        echo "WARNING: Failed to get 200 response from http://localhost:$port/version for app_$service (got $response)"
        echo "Full curl output for app_$service:"
        cat /tmp/response_output_${service}.txt
    else
        echo "Successfully accessed http://localhost:$port/version for app_$service"
    fi
done

echo "Deployment successful. Logs saved to $LOG_FILE"
echo "Test with: curl -v http://localhost:${PORT:-8080}/version"