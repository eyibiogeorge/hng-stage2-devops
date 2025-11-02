#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <blue|green>"
  exit 2
fi

TARGET="$1"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# Load environment
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

# Define upstreams
BLUE_ADDR="app_blue:8081"
GREEN_ADDR="app_green:8082"

if [ "$TARGET" = "blue" ]; then
  export PRIMARY_SERVER="$BLUE_ADDR"
  export BACKUP_SERVER="$GREEN_ADDR"
elif [ "$TARGET" = "green" ]; then
  export PRIMARY_SERVER="$GREEN_ADDR"
  export BACKUP_SERVER="$BLUE_ADDR"
else
  echo "Invalid pool: $TARGET"
  exit 2
fi

echo "🔄 Switching active pool to: $TARGET"
echo "Primary: $PRIMARY_SERVER"
echo "Backup:  $BACKUP_SERVER"

TEMPLATE_FILE="${PROJECT_ROOT}/nginx/nginx.conf.template"
GENERATED_FILE="${PROJECT_ROOT}/nginx/generated-nginx.conf"

# Render template
docker run --rm -i \
  -v "${TEMPLATE_FILE}":/in.conf \
  -v "${GENERATED_FILE}":/out.conf \
  -e PRIMARY_SERVER -e BACKUP_SERVER \
  alpine/sh -c "apk add --no-cache gettext >/dev/null && envsubst '\$PRIMARY_SERVER \$BACKUP_SERVER' < /in.conf > /out.conf"

echo "✅ Updated nginx config"

# Reload nginx gracefully
docker compose exec -T nginx nginx -s reload
echo "✅ Reloaded nginx — now serving $TARGET"
