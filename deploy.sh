#!/bin/bash
set -e

# Detect current running pool
CURRENT_POOL=$(docker ps --format '{{.Names}}' | grep -E 'app_blue|app_green' | grep -oE 'blue|green' | head -n1)

if [ "$CURRENT_POOL" == "blue" ]; then
    NEW_POOL="green"
else
    NEW_POOL="blue"
fi

RELEASE_ID="${NEW_POOL}-v$(date +%s)"

echo "🌀 Current active pool: $CURRENT_POOL"
echo "🔄 Switching to new pool: $NEW_POOL"

# Export for envsubst
export ACTIVE_POOL="${NEW_POOL}_pool"
export RELEASE_ID=$RELEASE_ID

# Confirm values
echo "ACTIVE_POOL=$ACTIVE_POOL"
echo "RELEASE_ID=$RELEASE_ID"

# Substitute explicitly
envsubst '${ACTIVE_POOL} ${RELEASE_ID}' < config/nginx.conf.template > config/nginx.conf

# Rebuild and restart
docker compose down
docker compose up -d --build

echo "✅ Blue/Green switch complete! Active pool: ${NEW_POOL}"

