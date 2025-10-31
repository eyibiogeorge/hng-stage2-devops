#!/bin/bash
set -e

# ===========================
# CONFIGURATION
# ===========================
ENV_FILE=".env"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "[ERROR] .env file not found!"
    exit 1
fi

# Check if Slack webhook is set
if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "[ERROR] SLACK_WEBHOOK_URL not set in .env"
    exit 1
fi

# ===========================
# FUNCTIONS
# ===========================
send_slack_notification() {
    local message="$1"
    local payload=$(jq -n --arg text "$message" '{text: $text}')

    echo "[INFO] Sending Slack notification..."
    curl -X POST -H "Content-type: application/json" \
        --data "$payload" \
        "$SLACK_WEBHOOK_URL" || echo "[WARN] Failed to send Slack message"
}

test_slack_webhook() {
    echo "[TEST] Testing Slack Webhook..."
    local test_message="✅ Slack webhook test from deploy.sh at $(date '+%Y-%m-%d %H:%M:%S')"
    send_slack_notification "$test_message"
    echo "[INFO] Test message sent to Slack."
}

# ===========================
# MAIN DEPLOY LOGIC
# ===========================
echo "[INFO] Starting deployment process..."

# Run Slack test once at startup
test_slack_webhook

# Example deploy logic (simplified)
docker compose down
docker compose up -d --build

if [ $? -eq 0 ]; then
    send_slack_notification "🚀 Deployment successful on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
else
    send_slack_notification "❌ Deployment failed on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
fi
