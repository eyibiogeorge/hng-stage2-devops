#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <blue|green>"
  exit 2
fi

TARGET="$1"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# Load .env
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

# Define upstreams inside Docker network
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

# Make sure the target file exists
mkdir -p "$(dirname "$GENERATED_FILE")"
touch "$GENERATED_FILE"

# Render template inside a temporary Alpine container (cleaner)
docker run --rm -i \
  -v "${TEMPLATE_FILE}":/in.conf \
  -v "${GENERATED_FILE}":/out.conf \
  -e PRIMARY_SERVER -e BACKUP_SERVER \
  alpine/sh -c "apk add --no-cache gettext >/dev/null && envsubst '\$PRIMARY_SERVER \$BACKUP_SERVER' < /in.conf > /out.conf"

echo "✅ Nginx config updated"

# Graceful reload
docker compose exec -T nginx nginx -s reload || {
  echo "⚠️  Nginx reload failed — ensure containers are up."
  exit 1
}

echo "✅ Switched active pool to: $TARGET"