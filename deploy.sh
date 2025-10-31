#!/usr/bin/env bash
set -e

# ===========================================
# 🟦 HNG Blue/Green Deployment Script
# ===========================================

ACTIVE_POOL_FILE=".active_pool"

if [ -f "$ACTIVE_POOL_FILE" ]; then
  ACTIVE_POOL=$(cat "$ACTIVE_POOL_FILE")
else
  ACTIVE_POOL="blue"
fi

if [ "$ACTIVE_POOL" == "blue" ]; then
  NEW_POOL="green"
else
  NEW_POOL="blue"
fi

echo "🌀 Current active pool: $ACTIVE_POOL"
echo "🔄 Switching to new pool: $NEW_POOL"

# Environment variables for substitution
export ACTIVE_POOL="${NEW_POOL}_pool"
export RELEASE_ID="${NEW_POOL}-$(date +%s)"

# Generate nginx.conf from template
envsubst '$ACTIVE_POOL $RELEASE_ID' < nginx/nginx.conf.template > nginx/nginx.conf

echo "✅ Generated nginx.conf for $NEW_POOL"

# Launch or update containers
docker compose up -d --build

# Test Nginx config inside container
echo "🔍 Testing Nginx configuration..."
docker compose exec nginx nginx -t

# Reload Nginx gracefully
echo "♻️ Reloading Nginx..."
docker compose exec nginx nginx -s reload || docker compose restart nginx

# Save current active pool
echo "$NEW_POOL" > "$ACTIVE_POOL_FILE"

echo "✅ Switched traffic to $NEW_POOL successfully."
