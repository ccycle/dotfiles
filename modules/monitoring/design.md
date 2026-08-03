# Monitoring Design

## Purpose

Answer "which subsystem is failing" for the self-hosted service stacks
(GitLab, Immich, OpenCloud) without SSH-and-grep archaeology: metrics in
Prometheus, logs in Loki, dashboards in Grafana, and machine-queryable APIs
for agent-driven investigation.

## Non-Goals

- **No alert notifications.** Alert rules are evaluated so their firing state
  is queryable via the Prometheus API and visible in Grafana, but there is no
  Alertmanager and no notification channel. Adding one is a deliberate future
  decision, not an oversight.
- No host-level (macOS) metrics: no node_exporter on the host.
- No Caddy metrics or access logs, and no blackbox/synthetic probing —
  reachability is covered by the smoke-test skills.
- No vendored community dashboards. Only compact hand-written dashboard JSONs
  are checked in; large community dashboards (e.g. grafana.com ID 193 for
  Docker) can be imported manually through the UI into the persistent Grafana
  volume if wanted.

## Why This Structure

- **Cross-stack scraping goes through host-published loopback ports and the
  `host-gateway` extra_host**, not a shared docker network. The service
  stacks are independent launchd-managed compose projects; a shared network
  would couple their startup order and lifecycle. The cost is that every
  scraped service must publish its metrics port on the host's 127.0.0.1.
- **GitLab is scraped with a minimal exporter set**, one signal per failure
  domain: Rails web metrics, sidekiq job execution, sidekiq queue backlog
  (only available from gitlab_exporter), postgres, redis. The bundled
  in-container node_exporter is disabled (cAdvisor already covers container
  resources; it would measure the Docker VM), and the bundled Prometheus and
  Alertmanager are disabled because this stack's Prometheus scrapes directly.
- **GitLab file logs are collected in addition to container stdout** because
  GitLab Omnibus writes its real logs (rails, sidekiq, gitaly, ...) to its
  log directory, not stdout. They are labeled with the same `compose_project`
  value as the container so one selector covers both.
- **Log lines get a normalized `level` label** extracted from JSON logs at
  collection time, so error filtering is a cheap label match rather than a
  full-text scan. `level` is bounded (safe cardinality); no other extracted
  field may be promoted to a label without considering cardinality.
- **Grafana is the human interface only.** Agent-driven investigation targets
  the Prometheus and Loki HTTP APIs directly (localhost, no auth); the
  `investigate-service` skill documents that contract. This is why datasource
  UIDs are pinned: dashboard JSONs and queries must be stable references.
- **Immich is instrumented the same way as GitLab**, one signal per failure
  domain: the app itself already exposes API/job telemetry
  (`IMMICH_TELEMETRY_INCLUDE=all`), so only the two dependencies it doesn't
  control — its bundled Postgres and Redis, neither of which ships an
  exporter — get sidecar `postgres_exporter`/`redis_exporter` containers.
  Immich's job-queue metrics only expose in-flight active count, not queued
  backlog, so there is no backlog alert for it (unlike GitLab's Sidekiq,
  which has a real backlog metric via `gitlab_exporter`).
- **OpenCloud is scraped from its debug port** (`PROXY_DEBUG_ADDR`), not
  port 9200 — oCIS/OpenCloud exposes Prometheus metrics on a separate debug
  HTTP server, not the app port. `opencloud-health.json` uses the
  `opencloud_proxy_*` and `reva_upload/download_active` metrics confirmed
  live post-deploy; `opencloud_proxy_requests_total` has no `status` label
  (unlike GitLab/Immich's HTTP metrics), so the error panel uses the
  dedicated `opencloud_proxy_errors_total` counter instead of a status-code
  breakdown.
- **Forgejo is scraped from its own web port** (`host-gateway:3000/metrics`),
  enabled with `FORGEJO__metrics__ENABLED`. Forgejo (Gitea fork) exposes only
  `gitea_*` instance statistics (repositories, users, issues open/closed,
  labels, ...) plus Go/process runtime — verified live on 11.x it has **no
  HTTP traffic/latency/error metrics**, so `forgejo-health.json` has no
  request panels and no HTTP-error alert; availability/restart are the
  generic `ScrapeTargetDown`/`ContainerRestarting` rules and the one distinct
  alert is file-descriptor pressure. `gitea_issues_by_label` /
  `gitea_issues_by_repository` only emit once issues exist (the collector
  skips empty maps), so their dashboard panels are empty on a fresh instance.
  Forgejo uses its embedded SQLite, so — unlike GitLab/Immich — there is no
  separate datastore exporter. Logs flow to Loki through the generic docker
  discovery with `compose_project=forgejo` (stdout, not file logs, so no
  Alloy change was needed unlike GitLab).

## Rejected Alternatives

- **Shared docker network between stacks** for scraping — rejected to keep
  stack lifecycles independent (see above).
- **Grafana MCP server** as the agent interface — rejected for now: the APIs
  are local and unauthenticated, so plain HTTP + a skill achieves the same
  with no service-account token to manage.
- **`prometheus_monitoring['enable'] = false`** as the way to disable
  GitLab's bundled Prometheus — rejected because it disables all bundled
  exporters too; the server and Alertmanager are disabled individually.
- **Loki ruler for log-based alerts** — rejected while there is no
  notification channel; Prometheus alert rules cover the triage-entry-point
  need.

## Constraints

- Every port published by a service stack must be unique across all stacks,
  because they all land on the host's 127.0.0.1. Check existing mappings
  before adding one; remap the container port when it collides.
- The Rails metrics endpoint is IP-whitelisted inside GitLab, and the
  effective client IP depends on the Docker runtime's NAT; the whitelist
  must stay broad enough to cover the runtime's bridge range.
- Compose files are static; anything host-dependent (hostname-derived URLs,
  storage paths) must flow in as environment variables exported by the
  launchd script.
