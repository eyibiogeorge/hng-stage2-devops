#!/bin/bash
set -e

echo "🌀 Detecting active pool..."
if [ -f .active_pool ]; then
  ACTIVE_POOL=$(cat .active_pool)
else
  ACTIVE_POOL="blue_pool"
fi

if [ "$ACTIVE_POOL" = "blue_pool" ]; then
  NEW_POOL="green_pool"
else
  NEW_POOL="blue_pool"
fi

echo "🔄 Switching to new pool: $NEW_POOL"
RELEASE_ID="${NEW_POOL}-v$(date +%s)"

# Save active pool
echo "$NEW_POOL" > .active_pool

# Export for envsubst
export ACTIVE_POOL=$NEW_POOL
export RELEASE_ID=$RELEASE_ID

echo "✅ Building Docker images..."
docker compose build --no-cache

echo "🧩 Generating Nginx configuration..."
envsubst < config/nginx.conf.template > config/nginx.conf

echo "✅ Nginx configuration generated:"
cat config/nginx.conf

docker compose down
docker compose up -d

echo "🚀 Deployment complete! Active pool: $NEW_POOL"