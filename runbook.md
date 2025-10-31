# 🧭 HNG Stage 2 DevOps — Blue/Green Deployment Runbook

## 📘 Overview
This runbook describes how to deploy, monitor, and test the **Blue/Green deployment system** for the HNG Stage 2 DevOps project.  
The project uses **Docker Compose** for container orchestration, **Nginx** as a reverse proxy, and a custom **Alert Watcher** that notifies a Slack channel of failover or high-error events.

---

## 🏗️ System Components
| Service | Description |
|----------|-------------|
| `app_blue` | Active/standby Node.js (TypeScript) application container |
| `app_green` | Alternate Node.js container for zero-downtime deployments |
| `nginx` | Load balancer and traffic router between Blue and Green pools |
| `alert_watcher` | Python service that monitors Nginx logs and sends Slack alerts |

---

## ⚙️ Environment Variables
Create a `.env` file in the project root with the following values:

```bash
ACTIVE_POOL=blue
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/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
🚀 Deployment Procedure
Step 1 — Build and Start All Services
bash
Copy code
docker compose up -d --build
✅ This command builds all containers, starts Nginx, the two app pools, and the alert watcher.

Verify all services are running:

bash
Copy code
docker compose ps
Step 2 — Check Application
Visit:

bash
Copy code
http://<server-ip>/
You should see a welcome page confirming that the app is running successfully.

🔁 Blue/Green Switch Procedure
To perform a zero-downtime switch between environments:

bash
Copy code
./deploy.sh
The script:

Detects the current active pool (blue or green).

Switches traffic to the alternate pool.

Regenerates the Nginx configuration.

Sends a Slack notification confirming the switch.

Expected Slack message:

✅ Blue/Green Switch Complete — Active Pool: green

🧨 Failover Event Test
This test verifies that Slack notifications work when one environment fails.

Steps:
Identify current active pool:

bash
Copy code
cat .env | grep ACTIVE_POOL
Stop that container to simulate a failure:

bash
Copy code
docker stop app_blue  # or app_green
Access your app:

bash
Copy code
curl http://localhost
You’ll see a connection failure (502/500).

Check Slack:
You should receive a message like:

🚨 Failover Event Detected — Active Pool (blue) is unreachable!

📸 Failover Event Screenshot
Take a screenshot showing:

Terminal logs with Failover detected

Slack alert in your workspace

⚠️ High Error Rate Alert Test
This test simulates a surge in error responses to trigger a high-error Slack alert.

Steps:
Stop one pool (e.g., Blue):

bash
Copy code
docker stop app_blue
Send multiple failed requests:

bash
Copy code
for i in {1..20}; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost; done
Check watcher logs:

bash
Copy code
docker compose logs -f hng-stage2-devops-alert_watcher
You’ll see:

scss
Copy code
[WARN] High error rate detected! (error_count=10)
[INFO] Sending Slack notification...
[ALERT] High Error Rate reported successfully.
Check Slack:

⚠️ High Error Rate Alert — Multiple 5xx errors detected in Blue service.

📸 High Error Rate Screenshot
Capture terminal logs and Slack message together.

🧰 Recovery Procedure
After tests:

bash
Copy code
docker start app_blue app_green
docker compose restart nginx
To clean up:

bash
Copy code
docker compose down
🧑‍💻 Troubleshooting
Issue	Cause	Solution
nginx: invalid number of arguments in directive	Bad Nginx syntax	Validate config/nginx.conf.template
host not found in upstream	Wrong upstream name	Ensure upstream blocks match app service names
curl: (7) couldn't connect to server	Nginx not running	Run docker compose restart nginx
Slack alert not sent	Wrong webhook or network issue	Verify SLACK_WEBHOOK_URL in .env

🏁 Verification Checklist
✅ App loads via Nginx
✅ Blue/Green switch works via deploy.sh
✅ Slack receives failover and high error rate alerts
✅ Both screenshots captured and saved

