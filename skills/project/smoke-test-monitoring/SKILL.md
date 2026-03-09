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

1. **Container Status**: Verifies all 5 monitoring containers are in `running` state via `docker compose ps`.
2. **Health Endpoints**: Curls each service's health endpoint on localhost to confirm HTTP 200:
   - Prometheus: `http://127.0.0.1:9090/-/healthy`
   - Grafana: `http://127.0.0.1:3000/api/health`
   - Loki: `http://127.0.0.1:3100/ready`
   - cAdvisor: `http://127.0.0.1:8081/healthz`
3. **Caddy Reverse Proxy**: Verifies HTTPS access through Caddy:
   - `https://grafana.mac-mini-m4.internal`
   - `https://prometheus.mac-mini-m4.internal`

## When to Use

- After `darwin-rebuild switch` to verify the monitoring stack deployed correctly.
- When debugging monitoring service issues.
