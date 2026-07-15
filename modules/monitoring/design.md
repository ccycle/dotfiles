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
