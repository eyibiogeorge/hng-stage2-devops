import os, time, requests
from collections import deque

LOG_PATH = "/var/log/nginx/access.log"
WEBHOOK = os.getenv("SLACK_WEBHOOK_URL")
THRESHOLD = float(os.getenv("ERROR_RATE_THRESHOLD", "2"))
WINDOW_SIZE = int(os.getenv("WINDOW_SIZE", "200"))
COOLDOWN = int(os.getenv("ALERT_COOLDOWN_SEC", "300"))
MAINTENANCE = os.getenv("MAINTENANCE_MODE", "false").lower() == "true"

error_window = deque(maxlen=WINDOW_SIZE)
last_pool = None
last_alert_time = 0

def post_to_slack(message):
    global last_alert_time
    if MAINTENANCE or not WEBHOOK: return
    now = time.time()
    if now - last_alert_time < COOLDOWN: return
    requests.post(WEBHOOK, json={"text": message})
    last_alert_time = now

def parse_line(line):
    parts = dict(item.split("=") for item in line.split() if "=" in item)
    return parts.get("pool"), parts.get("upstream_status")

with open(LOG_PATH, "r") as f:
    f.seek(0, 2)
    while True:
        line = f.readline()
        if not line:
            time.sleep(0.5)
            continue
        pool, status = parse_line(line)
        if pool and pool != last_pool:
            post_to_slack(f":twisted_rightwards_arrows: Failover detected → {last_pool} → {pool}")
            last_pool = pool
        if status and status.startswith("5"):
            error_window.append(1)
        else:
            error_window.append(0)
        error_rate = sum(error_window) / len(error_window) * 100
        if error_rate > THRESHOLD:
            post_to_slack(f":rotating_light: High error rate detected → {error_rate:.2f}% over last {WINDOW_SIZE} requests")