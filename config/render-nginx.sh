#!/bin/bash
set -e

# Default to blue if not specified
: "${ACTIVE_POOL:=blue}"

echo "🔧 Generating nginx.conf with ACTIVE_POOL=$ACTIVE_POOL"

# Render template safely, preserving newlines
cat /etc/nginx/nginx.conf.template | tr -d '\r' | envsubst '$ACTIVE_POOL' > /etc/nginx/nginx.conf

echo "✅ nginx.conf generated successfully"
cat /etc/nginx/nginx.conf | sed -n '10,30p'

# Continue to the original entrypoint
exec "$@"
