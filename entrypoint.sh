#!/bin/sh
set -e

# Default value for release id if not provided
: "${RELEASE_ID:=unknown}"

echo "----------------------------------------"
echo "🟢 Starting Nginx Blue/Green Proxy"
echo "Active pool: ${ACTIVE_POOL}"
echo "Blue: ${BLUE_HOST}:${BLUE_PORT}"
echo "Green: ${GREEN_HOST}:${GREEN_PORT}"
echo "Release ID: ${RELEASE_ID}"
echo "----------------------------------------"

# Render nginx.conf with environment variables
envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "✅ Generated nginx.conf successfully."
echo "🔍 Testing Nginx configuration..."
if ! nginx -t; then
    echo "❌ Nginx configuration test failed. Check /etc/nginx/nginx.conf."
    cat /etc/nginx/nginx.conf
    exit 1
fi

echo "🚀 Launching Nginx in foreground mode..."
exec nginx -g 'daemon off;'
