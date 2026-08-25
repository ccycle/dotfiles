---
name: e2e-test-monitoring
description: Run API-driven (plus one browser-rendered) E2E checks of the monitoring stack's real Prometheus scrape config, Grafana local-admin login/dashboard, and Loki log ingestion, against an isolated per-worktree stack — never production.
---

# Monitoring E2E Test (Prometheus + Grafana + Loki)

Drives Prometheus's real `/api/v1/targets` and `/api/v1/query`, Grafana's
real local-admin login and dashboard API, a real browser render of a
Grafana dashboard, and Loki's real `/loki/api/v1/query_range` - all
against an isolated stack that deliberately still scrapes the _real_
host via `host-gateway`, using the real `modules/monitoring/prometheus.yml`
(mounted unmodified). See `tests/e2e-monitoring/design.md` for the full
rationale, including why target _health_ is never asserted (only that
every configured job was discovered) and why this suite uses local auth
instead of OIDC.

This never touches the real `services.monitoring` instance on
`mac-mini-m4-pro` or its data. It brings up a separate, isolated
docker-compose stack (project name derived from the worktree's directory
name), with its own throwaway ports and Grafana volume.

## Usage

Run from anywhere inside the repository (any worktree):

```bash
.agents/skills/e2e-test-monitoring/scripts/run.sh
```

## What It Does

1. Brings up an isolated Prometheus/Grafana/Loki/Alloy/cAdvisor stack,
   waits for Prometheus and Grafana's health endpoints.
2. Confirms every `job_name` in the real `prometheus.yml` has a
   discovered target, and that Prometheus reports itself `up` via a
   live query.
3. Logs into Grafana's local admin via the API, fetches the real
   `services-overview` dashboard, and confirms it has panels.
4. Logs into Grafana through a real browser, opens that same dashboard,
   and confirms it renders with zero console/page errors.
5. Confirms Loki actually received log lines (via Alloy tailing every
   container on the host, including this stack's own).
6. Publishes Playwright's own HTML report (trace: 'on') to
   `modules/static-reports`'s `dataDir` under `<branch-slug>/monitoring/`
   (pruned after 14 days of inactivity) - after `services.staticReports`
   has been applied via `darwin-rebuild switch`, it's browsable at
   `https://reports.<hostname>.internal/<branch-slug>/monitoring/` from
   any device on the tailnet after a Pocket ID passkey login.
   Best-effort: a worktree on a host without
   that module enabled doesn't fail the test run over it.
7. Tears the stack (containers + volumes + data dirs) down completely,
   so every run starts from a clean instance.

## When to Use

- After changing `modules/monitoring/prometheus.yml`,
  `loki-config.yml`, `alloy-config.alloy`, or any Grafana provisioning/
  dashboard JSON, to confirm the real config still loads and works -
  something a build dry-run structurally cannot verify.
- After adding a new scrape job for a service, to confirm it's actually
  discovered (this suite reads job names straight from the real
  `prometheus.yml`, so a newly-added job is covered automatically, no
  test-code change needed).

## Known Constraints

- Docker must be running.
- First run in a given worktree does `npm install` (Playwright + its test
  runner) before the suite itself starts.
- Target _health_ depends on what's actually running on this host at
  test time - every job except `job="prometheus"` may legitimately
  report down, and that's not treated as a failure (see design.md).
