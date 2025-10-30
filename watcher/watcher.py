import os
import time
import requests
import subprocess
from collections import deque

# Configuration from environment
LOG_PATH = "/var/log/nginx/access.log"
WEBHOOK = os.getenv("https://hooks.slack.com/services/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")
THRESHOLD = float(os.getenv("ERROR_RATE_THRESHOLD", "2"))
WINDOW_SIZE = int(os.getenv("WINDOW_SIZE", "200"))
COOLDOWN = int(os.getenv("ALERT_COOLDOWN_SEC", "300"))
MAINTENANCE = os.getenv("MAINTENANCE_MODE", "false").lower() == "true"

# State
error_window = deque(maxlen=WINDOW_SIZE)
last_pool = None
last_alert_time = 0

def post_to_slack(message):
    global last_alert_time
    if MAINTENANCE or not WEBHOOK:
        return
    now = time.time()
    if now - last_alert_time < COOLDOWN:
        return
    try:
        requests.post(WEBHOOK, json={"text": message})
        last_alert_time = now
    except Exception as e:
        print(f"Slack alert failed: {e}")

def parse_line(line):
    parts = dict(item.split("=", 1) for item in line.split() if "=" in item)
    return parts.get("pool"), parts.get("upstream_status")

def stream_logs():
    while not os.path.exists(LOG_PATH):
        print(f"Waiting for log file: {LOG_PATH}")
        time.sleep(1)
    process = subprocess.Popen(["tail", "-F", LOG_PATH], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    for line in process.stdout:
        yield line.strip()

# Main loop
for line in stream_logs():
    pool, status = parse_line(line)
    if pool and pool != last_pool:
        post_to_slack(f":twisted_rightwards_arrows: Failover detected → {last_pool or 'unknown'} → {pool}")
        last_pool = pool
    if status and status.startswith("5"):
        error_window.append(1)
    else:
        error_window.append(0)
    if len(error_window) == WINDOW_SIZE:
        error_rate = sum(error_window) / len(error_window) * 100
        if error_rate > THRESHOLD:
            post_to_slack(f":rotating_light: High error rate detected → {error_rate:.2f}% over last {WINDOW_SIZE} requests")