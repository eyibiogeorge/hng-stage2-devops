# 🧭 HNG Stage 2 DevOps — Alert & Incident Response Runbook

## 📘 Overview
This document explains the **alert system**, **notification meanings**, and the **required actions** operators must take when an alert is triggered.

The alert system is powered by the `alert_watcher` container, which continuously monitors:
- **Nginx logs** for HTTP errors (5xx, 4xx)
- **Service status** for Blue/Green app pools
- **Deployment switch events**

Alerts are delivered via **Slack Webhook**, ensuring real-time visibility into service health.

---

## 🚨 Alert Categories

| Alert Type | Source | Trigger Condition | Notification Channel |
|-------------|---------|------------------|-----------------------|
| ✅ **Deployment Complete** | `deploy.sh` script | When a Blue/Green switch completes successfully | Slack |
| 🚨 **Failover Event** | `alert_watcher` | When active pool (blue/green) becomes unresponsive | Slack |
| ⚠️ **High Error Rate** | `alert_watcher` | When 10 or more 5xx errors occur within 1 minute | Slack |
| 💤 **Service Down** | `alert_watcher` | When any container (app, nginx, watcher) stops | Slack |
| 🧱 **Configuration Error** | `nginx` | When syntax or routing issues prevent Nginx from starting | Docker Logs |

---

## ✅ Deployment Complete
**Example Slack Message:**
> ✅ Blue/Green Switch Complete — Active Pool: green

### Meaning:
- Deployment succeeded.
- Nginx config reloaded successfully.
- All containers are healthy and serving traffic.

### Operator Actions:
- Verify that `curl http://<server-ip>` returns the app page.
- No further action required unless alert_watcher reports follow-up issues.

---

## 🚨 Failover Event
**Example Slack Message:**
> 🚨 Failover Event Detected — Active Pool (blue) is unreachable!

### Meaning:
- The current live application (Blue or Green) stopped responding.
- The watcher detected failed health checks or unreachable upstream.
- Nginx might have switched traffic to the standby environment (if configured).

### Possible Causes:
- App container crashed.
- Network interruption between app and Nginx.
- Node.js process failed due to runtime error.
- Memory or port exhaustion.

### Operator Actions:
1. Run health check:
   ```bash
   docker ps
Restart the failed service:

bash
Copy code
docker restart app_blue  # or app_green
Review app logs:

bash
Copy code
docker logs app_blue --tail 50
Confirm recovery:

bash
Copy code
curl http://localhost
Post incident summary to Slack (optional):

✅ Service restored after failover — Root cause: [describe issue]

⚠️ High Error Rate
Example Slack Message:

⚠️ High Error Rate Alert — Multiple 5xx errors detected in Blue service.

Meaning:
Watcher detected a sustained error pattern (e.g., 10+ server errors in 60 seconds).

Indicates degraded performance or partial outage.

Possible Causes:
Database or external API failure.

Code regression in latest deployment.

Nginx routing errors or resource bottleneck.

Operator Actions:
Check watcher logs:

bash
Copy code
docker compose logs -f hng-stage2-devops-alert_watcher
Inspect Nginx logs:

bash
Copy code
docker compose logs -f nginx
Restart app containers if necessary:

bash
Copy code
docker restart app_blue app_green
Investigate specific endpoints or functions generating errors.

Document findings and notify the dev team.

💤 Service Down
Example Slack Message:

💤 Service Down — Nginx container stopped unexpectedly.

Meaning:
Docker reported that a critical container exited or crashed.

Could be due to configuration errors, OOM (Out Of Memory), or manual stop.

Operator Actions:
Identify stopped container:

bash
Copy code
docker ps -a
Restart it:

bash
Copy code
docker start <container_name>
Review crash logs:

bash
Copy code
docker logs <container_name> --tail 50
If service repeatedly fails, run:

bash
Copy code
docker compose down && docker compose up -d --build
🧱 Configuration Error
Example Docker Logs:

typescript
Copy code
nginx  | [emerg] invalid number of arguments in "proxy_set_header" directive
Meaning:
Nginx configuration file (nginx.conf.template) has a syntax error.

The service failed to start or reload due to invalid directives.

Operator Actions:
Check Nginx logs:

bash
Copy code
docker compose logs nginx
Validate configuration:

bash
Copy code
docker compose exec nginx nginx -t
Correct syntax in config/nginx.conf.template.

Rebuild container:

bash
Copy code
docker compose up -d --build
🧩 Slack Notification Troubleshooting
If no alerts appear in Slack:

Check webhook variable:

bash
Copy code
echo $SLACK_WEBHOOK_URL
Test manually:

bash
Copy code
curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"🔔 Slack Test Notification"}' \
     $SLACK_WEBHOOK_URL
Ensure container has internet access:

bash
Copy code
docker exec -it hng-stage2-devops-alert_watcher ping google.com
Restart the watcher:

bash
Copy code
docker restart hng-stage2-devops-alert_watcher
🧰 Summary of Operator Workflow
Scenario	Operator Response
Deployment alert	Validate success with curl http://localhost
Failover alert	Restart affected app and confirm recovery
High error rate	Investigate logs and check backend/API
Service down	Restart stopped containers
Config error	Fix Nginx config and rebuild
No Slack alerts	Verify webhook connectivity

🏁 Notes
The alert_watcher container is the first line of defense for real-time monitoring.

Always verify container health after deployments or failover tests.

Document all incident responses for future improvements.