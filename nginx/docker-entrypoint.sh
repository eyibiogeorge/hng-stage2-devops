#!/bin/sh
set -e

echo "[INFO] Rendering Nginx config from template..."
envsubst '$ACTIVE_POOL $BLUE_PORT $GREEN_PORT $BLUE_RELEASE_ID $GREEN_RELEASE_ID' \
  < /etc/nginx/nginx.conf.template \
  > /etc/nginx/conf.d/default.conf

echo "[INFO] Starting Nginx..."
exec nginx -g "daemon off;"
