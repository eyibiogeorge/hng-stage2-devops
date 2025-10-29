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
    exit "$2"
}
trap 'cleanup $LINENO $?' ERR

# Check for required files
echo "Checking for required files..."
for file in docker-compose.yml config/nginx.conf.template .env Dockerfile.nginx; do
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

# Pull images to ensure they are available
echo "Pulling Docker images..."
docker pull "$BLUE_IMAGE"
docker pull "$GREEN_IMAGE"

# Run Docker Compose
echo "Starting Docker Compose..."
docker-compose up -d --build

# Validate deployment
echo "Validating deployment..."
sleep 5
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT:-8080}/version)
if [[ "$response" != "200" ]]; then
    echo "ERROR: Failed to get 200 response from http://localhost:${PORT:-8080}/version"
    docker-compose logs nginx
    docker-compose logs app_blue
    docker-compose logs app_green
    exit 1
fi

# Verify headers
echo "Verifying response headers..."
headers=$(curl -s -I http://localhost:${PORT:-8080}/version)
if ! echo "$headers" | grep -q "X-App-Pool: ${ACTIVE_POOL}"; then
    echo "ERROR: X-App-Pool header does not match ACTIVE_POOL (${ACTIVE_POOL})"
    exit 1
fi
if ! echo "$headers" | grep -q "X-Release-Id: ${RELEASE_ID_${ACTIVE_POOL^^}}"; then
    echo "ERROR: X-Release-Id header does not match expected value"
    exit 1
fi

echo "Deployment successful. Logs saved to $LOG_FILE"
echo "Test with: curl -v http://localhost:${PORT:-8080}/version"