#!/bin/bash
set -e

echo ""
echo "🚀 Starting Blue-Green Deployment..."

# Load environment variables
source .env

# Determine active/inactive pools
if [ "$ACTIVE_POOL" = "blue" ]; then
  NEW_POOL="green"
else
  NEW_POOL="blue"
fi

echo "🌀 Current active pool: $ACTIVE_POOL"
echo "🔄 Switching to new pool: $NEW_POOL"

# Update .env to reflect new active pool
sed -i "s/ACTIVE_POOL=$ACTIVE_POOL/ACTIVE_POOL=$NEW_POOL/" .env

# Rebuild nginx configuration using envsubst
export ACTIVE_POOL=$NEW_POOL
envsubst '$ACTIVE_POOL $BLUE_HOST $BLUE_PORT $GREEN_HOST $GREEN_PORT' \
  < ./config/nginx.conf.template > ./config/nginx.conf.generated

echo "✅ Generated nginx.conf for pool: $NEW_POOL"

# Recreate services
docker compose down
docker compose up -d --build

echo "🔍 Testing Nginx configuration..."
sleep 3

# Verify nginx container is healthy
if docker compose ps nginx | grep -q "running"; then
  echo "✅ Nginx started successfully and is routing to $NEW_POOL pool."
else
  echo "❌ Nginx failed to start. Check logs:"
  docker compose logs nginx
  exit 1
fi

echo "🎉 Deployment complete! Active pool is now: $NEW_POOL"


