---
name: investigate-service
description: Investigate a service problem (GitLab, Immich, OpenCloud, monitoring) using the Prometheus and Loki APIs. Use when a service is down, slow, erroring, or a smoke test failed and the root cause is unknown.
---

# Service Investigation

Root-cause a service problem using the local observability stack. Both APIs are
on localhost with no auth: Prometheus at `http://127.0.0.1:9090`, Loki at
`http://127.0.0.1:3100`. Grafana is the human UI; for investigation, query the
APIs directly.

## Triage flow

Work down this list; stop when the failing layer is found.

1. **What is firing?** Alert rules are evaluated without notifications, so
   check firing state first:

   ```bash
   curl -s http://127.0.0.1:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, state: .state, labels: .labels}'
   ```

2. **Which scrape targets are down?**

   ```bash
   curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up") | {job: .labels.job, health, lastError}'
   ```

3. **Container state** for the affected stack (compose projects: `gitlab`,
   `immich`, `opencloud`, `forgejo`, `monitoring`):

   ```bash
   docker compose -p <project> ps
   ```

   The launchd daemon output for each stack is in `/var/log/<project>.log`.

4. **Error logs** for the affected service (see label schema below):

   ```bash
   logcli --addr=http://127.0.0.1:3100 query --since=1h '{compose_project="gitlab", level=~"error|fatal"}'
   # Without logcli:
   curl -sG http://127.0.0.1:3100/loki/api/v1/query_range \
     --data-urlencode 'query={compose_project="gitlab"} |~ "(?i)(error|fatal|panic)"' \
     --data-urlencode 'since=1h' --data-urlencode 'limit=100' \
     | jq -r '.data.result[].values[][1]'
   ```

5. **Correlate with metrics** around the failure time (`query_range`):

   ```bash
   curl -sG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=<promql>'
   ```

## Log label schema (Loki)

| Label | Values / meaning |
|---|---|
| `compose_project` | `gitlab`, `immich`, `opencloud`, `forgejo`, `monitoring` — covers container stdout AND GitLab file logs |
| `compose_service` | compose service name (e.g. `immich-server`, `gitlab-ce`) |
| `container_name` | docker container name |
| `level` | normalized lowercase level extracted from JSON logs (`error`, `warn`, ...); absent on non-JSON lines |
| `source` | `host` (files from /var/log) or `gitlab-file` (GitLab's on-disk logs) |
| `gitlab_component` | for `source="gitlab-file"`: subdirectory, e.g. `gitlab-rails`, `sidekiq`, `gitaly`, `nginx` |

GitLab's real logs (rails `production_json.log`, `sidekiq`, `gitaly`, ...) are
file logs, not container stdout — filter with
`{source="gitlab-file", gitlab_component="gitlab-rails"}`.

## Metrics job map (Prometheus)

| Job | What it tells you |
|---|---|
| `gitlab-rails` | web request rate/latency/errors (`/-/metrics`) |
| `gitlab-sidekiq` | background job execution: completed/failed |
| `gitlab-exporter-sidekiq` | queue backlog: `sidekiq_queue_size`, `sidekiq_queue_latency_seconds` |
| `gitlab-postgres` / `gitlab-redis` | datastore health: `pg_up`, `redis_up`, connections, memory |
| `immich-api` / `immich-microservices` | Immich internals |
| `forgejo` | Forgejo instance stats + Go/process runtime (no HTTP metrics; `gitea_issues_by_label`/`by_repository` emit only once issues exist) |
| `cadvisor` | per-container CPU/memory/restarts (labels `container_label_com_docker_compose_project`, `name`) |

## Reporting

Summarize: which layer failed (proxy / container / app subsystem / datastore),
the evidence (alert, metric, log lines with timestamps), and the earliest
abnormal signal you found.
