# 🚀 HNG Stage 2 DevOps — Blue-Green Deployment with Automated Alerting

This project demonstrates a **Blue-Green Deployment setup** using **Docker Compose**, **Nginx load balancing**, and a **custom Alert Watcher** that sends notifications to Slack during failovers or error spikes.

---

## 🧩 Project Structure

├── app_blue/ # Blue environment (Node.js/TypeScript app)
├── app_green/ # Green environment (Node.js/TypeScript app)
├── config/
│ └── nginx.conf.template # Nginx reverse proxy configuration
├── watcher/
│ └── alert_watcher.js # Slack-integrated alert watcher
├── docker-compose.yml # Multi-service orchestration
├── deploy.sh # Automated blue/green switch script
├── RUNBOOK.md # Alert handling and operator actions
└── README.md # Setup and usage guide

yaml
Copy code

---

## ⚙️ Setup Instructions

### 1️⃣ Clone the Repository
```bash
git clone https://github.com/<your-username>/hng-stage2-devops.git
cd hng-stage2-devops
2️⃣ Configure Slack Webhook
Create a Slack Incoming Webhook in your workspace and export it as an environment variable:

bash
Copy code
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXXXXXXXX/YYYYYYYYY/ZZZZZZZZZZZZ"
(You can add this line to your .env file for persistence.)

3️⃣ Start All Services
Run all containers in the background:

bash
Copy code
docker compose up -d --build
This starts:

nginx – reverse proxy & traffic router

app_blue and app_green – Node.js application servers

alert_watcher – health and log monitoring service

4️⃣ Verify Running Containers
bash
Copy code
docker ps
You should see containers for:

nginx

app_blue

app_green

hng-stage2-devops-alert_watcher

5️⃣ Access the Application
Visit:

arduino
Copy code
http://localhost
You’ll see a welcome page indicating which pool (Blue or Green) is active.

🧪 Chaos Testing (Failover Simulation)
Simulate different failure events to validate your alert system:

🔹 Test 1 — Blue App Failure
Stop the active container:

bash
Copy code
docker stop app_blue
Expected:
Slack should receive a message:

🚨 Failover Event Detected — Active Pool (blue) is unreachable!

🔹 Test 2 — High Error Rate
Send repeated invalid requests to generate 5xx errors:

bash
Copy code
for i in {1..15}; do curl http://localhost/invalid; done
Expected:
Slack should alert:

⚠️ High Error Rate Alert — Multiple 5xx errors detected in Blue service.

🔹 Test 3 — Service Restart
bash
Copy code
docker restart nginx
Expected:
You should see a new ✅ Deployment Complete message after successful reload.

🪵 Viewing Logs
View Nginx Logs
bash
Copy code
docker compose logs -f nginx
View Application Logs
bash
Copy code
docker compose logs -f app_blue
docker compose logs -f app_green
View Alert Watcher Logs
bash
Copy code
docker compose logs -f hng-stage2-devops-alert_watcher
💬 Verifying Slack Alerts
To confirm Slack connectivity manually:

bash
Copy code
curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"🔔 Test Notification from HNG DevOps"}' \
     $SLACK_WEBHOOK_URL
If you see the message in your Slack channel, alerting is working correctly.

🖼️ Reference Screenshots
Screenshot	Description
Deployment Complete Screenshot	Slack message confirming Blue/Green switch
Failover Event Screenshot	Slack alert showing failed active pool
High Error Rate Screenshot	Slack alert when excessive 5xx errors are detected

All screenshots can be found in the screenshots/ directory of this repository.

🧭 Additional Resources
RUNBOOK.md — Detailed guide on interpreting alerts and response actions.

Nginx Config Template — Logic for routing between blue and green pools.

Alert Watcher Script — Slack integration logic.

🧑‍💻 Maintainer
Name: George Eyibio
Version: v2.1
Last Updated: October 31, 2025

✅ Project Goal:
Demonstrate an automated Blue-Green Deployment pipeline with Slack-based monitoring and incident response — following DevOps best practices.

