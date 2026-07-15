---
name: smoke-test-monitoring
description: Run smoke tests against the monitoring stack to verify all containers are running and healthy after deployment.
---

# Monitoring Stack Smoke Test

Verifies that the monitoring stack (Prometheus, Grafana, Loki, Alloy, cAdvisor) is running correctly after `darwin-rebuild switch`.

## Usage

Run from the repository root:

```bash
skills/project/smoke-test-monitoring/scripts/test.sh
```

## Checks Performed

1. **Container Status**: Verifies all 5 monitoring containers are in `running` state via `docker compose -p monitoring ps`.
2. **Health Endpoints**: Curls each service's health endpoint on localhost to confirm HTTP 200:
   - Prometheus: `http://127.0.0.1:9090/-/healthy`
   - Grafana: `http://127.0.0.1:3000/api/health`
   - Loki: `http://127.0.0.1:3100/ready`
   - cAdvisor: `http://127.0.0.1:8081/healthz`
3. **Caddy Reverse Proxy**: Verifies HTTPS access through Caddy:
   - `https://grafana.<hostname>.internal`
   - `https://prometheus.<hostname>.internal`
4. **Prometheus Scrape Targets**: Queries `/api/v1/targets` and asserts every configured job (including the GitLab and Immich targets) reports `health: up`.
5. **Provisioned Dashboards**: Confirms the repo-managed dashboard JSONs are mounted inside the Grafana container.

## When to Use

- After `darwin-rebuild switch` to verify the monitoring stack deployed correctly.
- When debugging monitoring service issues.
- Note: GitLab targets need GitLab itself to be up; run this after GitLab has become healthy (5+ minutes after first boot).
