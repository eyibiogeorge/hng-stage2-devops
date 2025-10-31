import time
import os

def watch_logs():
    log_path = "/var/log/nginx/error.log"
    print("👀 Alert watcher started — monitoring blue/green deployments...")
    while True:
        time.sleep(30)
        if os.path.exists(log_path):
            with open(log_path) as f:
                lines = f.readlines()[-5:]
                for line in lines:
                    print("📜 Log:", line.strip())
        time.sleep(10)

if __name__ == "__main__":
    print("👁️ Starting Nginx log watcher...")
    watch_logs()
