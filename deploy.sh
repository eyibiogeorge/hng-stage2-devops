#!/bin/bash
set -e

CURRENT_POOL=$(docker compose ps --status=running | grep app_blue || true)
if [ -n "$CURRENT_POOL" ]; then
    ACTIVE_POOL="green"
    OLD_POOL="blue"
else
    ACTIVE_POOL="blue"
    OLD_POOL="green"
fi

echo "🌀 Current active pool: ${OLD_POOL:-none}"
echo "🔄 Switching to new pool: $ACTIVE_POOL"

export ACTIVE_POOL="${ACTIVE_POOL}_pool"
export RELEASE_ID="${ACTIVE_POOL}-v1"

envsubst < config/nginx.conf.template > config/nginx.conf

docker compose down
docker compose up -d --build

echo "✅ Blue/Green switch complete! Active pool: $ACTIVE_POOL"