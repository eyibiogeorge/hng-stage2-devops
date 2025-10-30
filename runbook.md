# Runbook: Observability & Alerts

## Failover Detected
**Alert:** Pool changed from Blue to Green (or vice versa)  
**Action:** Check health of primary container. Use `docker compose ps` and inspect logs.

## High Error Rate
**Alert:** >2% 5xx errors over last 200 requests  
**Action:** Check upstream logs, inspect app container health, consider toggling pools.

## Recovery
**Alert:** Error rate drops below threshold  
**Action:** Resume normal operations.

## Maintenance Mode
Set `MAINTENANCE_MODE=true` in `.env` to suppress alerts during planned toggles.